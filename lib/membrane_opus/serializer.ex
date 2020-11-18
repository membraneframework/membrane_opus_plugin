defmodule Membrane.Opus.Serializer do
  @moduledoc """
  Converts Opus stream to self-delimiting version.

  In the basic version of Opus packet coding, one frame size needs to be derived from
  the size of entire packet. This serializer adds the lacking size to each packet header,
  and thus converts packets to self-delimiting version.
  See https://tools.ietf.org/html/rfc6716#appendix-B for details.
  """
  use Membrane.Filter

  alias Membrane.{Buffer, Opus, RemoteStream}
  alias Membrane.Opus.PacketUtils

  def_input_pad :input,
    demand_unit: :buffers,
    caps: [
      {Opus, self_delimiting?: false},
      {RemoteStream, type: :packetized, content_format: one_of([nil, Opus])}
    ]

  def_output_pad :output, caps: {Opus, self_delimiting?: true}

  @impl true
  def handle_init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_caps(:input, caps, _ctx, state) do
    {{:ok, caps: {:output, %Opus{caps | self_delimiting?: true}}}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    %Buffer{payload: payload} = buffer
    {:ok, %{code: code}, data} = PacketUtils.skip_toc(payload)
    {:ok, mode, frames_cnt, padding_len, data} = PacketUtils.skip_code(code, data)
    {:ok, frames_size, body} = PacketUtils.skip_frame_sizes(mode, data, max(0, frames_cnt - 1))
    header_size = byte_size(payload) - byte_size(body)
    <<header::binary-size(header_size), _rest::binary>> = payload
    last_frame_size = PacketUtils.encode_frame_size(byte_size(body) - frames_size - padding_len)
    buffer = %Buffer{buffer | payload: header <> last_frame_size <> body}
    {{:ok, buffer: {:output, buffer}}, state}
  end
end
