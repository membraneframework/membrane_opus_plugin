defmodule Membrane.Opus.Parser do
  @moduledoc """
  Parses self-delimiting Opus stream.

  The self-delimiting version of Opus packet contains all the information about frame sizes
  needed to separate the packet from byte stream and decode it. This parser drops the last frame size
  from each packet header, converting packets to the basic version. The remaining frame size needs
  to be derived from entire packet size.
  See https://tools.ietf.org/html/rfc6716#appendix-B for details.
  """
  use Membrane.Filter

  alias Membrane.{Buffer, Opus, RemoteStream}
  alias Membrane.Opus.PacketUtils

  def_input_pad :input,
    demand_unit: :buffers,
    caps: [{Opus, self_delimiting?: true}, {RemoteStream, content_format: one_of([Opus, nil])}]

  def_output_pad :output, caps: {Opus, self_delimiting?: false}

  @impl true
  def handle_init(_opts) do
    {:ok, %{partial_packet: <<>>, timestamp: 0}}
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_demand(:output, _size, _unit, _ctx, state) do
    {{:ok, demand: {:input, 1}}, state}
  end

  @impl true
  def handle_process(:input, buffer, ctx, state) do
    payload = state.partial_packet <> buffer.payload

    caps =
      if !ctx.pads.output.caps do
        {:ok, %{channels: channels}, _data} = PacketUtils.skip_toc(payload)
        [caps: {:output, %Opus{channels: channels}}]
      else
        []
      end

    {payloads, partial_packet} = parse_packets(payload, [])

    {buffers, timestamp} =
      Enum.map_reduce(payloads, state.timestamp, fn {payload, duration}, timestamp ->
        {%Buffer{payload: payload, metadata: %{timestamp: timestamp}}, timestamp + duration}
      end)

    state = %{state | partial_packet: partial_packet, timestamp: timestamp}
    {{:ok, caps ++ [buffer: {:output, buffers}, redemand: :output]}, state}
  end

  defp parse_packets(payload, parsed_packets) do
    with {:ok, %{frame_duration: frame_duration, code: code}, data} <-
           PacketUtils.skip_toc(payload),
         {:ok, mode, frames_cnt, padding_len, data} <- PacketUtils.skip_code(code, data),
         {:ok, _preserved_frames_size, rest} <-
           PacketUtils.skip_frame_sizes(mode, data, max(0, frames_cnt - 1)),
         new_header_size = byte_size(payload) - byte_size(rest),
         {:ok, frames_size, data} <- PacketUtils.skip_frame_sizes(mode, data, frames_cnt),
         body_size = frames_size + padding_len,
         <<body::binary-size(body_size), remaining_packets::binary>> <- data do
      <<new_header::binary-size(new_header_size), _rest::binary>> = payload

      parse_packets(remaining_packets, [
        {new_header <> body, frame_duration * frames_cnt} | parsed_packets
      ])
    else
      _end_of_data -> {Enum.reverse(parsed_packets), payload}
    end
  end
end
