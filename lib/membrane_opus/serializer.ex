defmodule Membrane.Opus.Serializer do
  @moduledoc """
  Converts Opus stream to self-delimiting version.

  See https://tools.ietf.org/html/rfc6716#appendix-B for details.
  """
  use Membrane.Filter

  alias Membrane.{Buffer, Opus, Stream}
  alias Membrane.Opus.PacketUtils

  def_input_pad :input,
    demand_unit: :buffers,
    caps: [
      {Opus, self_delimiting?: false},
      {Stream, type: :packet_stream, content: one_of([nil, Opus])}
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
    {:ok, mode, frames, padding, data} = PacketUtils.skip_code(code, data)
    {:ok, frames_size, body} = PacketUtils.skip_frame_sizes(mode, data, max(0, frames - 1))
    header_size = byte_size(payload) - byte_size(body)
    <<header::binary-size(header_size), _rest::binary>> = payload
    last_frame_size = PacketUtils.encode_frame_size(byte_size(body) - frames_size - padding)
    buffer = %Buffer{buffer | payload: header <> last_frame_size <> body}
    {{:ok, buffer: {:output, buffer}}, state}
  end
end
