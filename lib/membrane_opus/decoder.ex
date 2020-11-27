defmodule Membrane.Opus.Decoder do
  @moduledoc """
  This element performs decoding of Opus audio.
  """

  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.{Buffer, Opus, RemoteStream}
  alias Membrane.Caps.Audio.Raw

  @avg_opus_packet_size 960

  def_options sample_rate: [
                spec: 8000 | 12000 | 16000 | 24000 | 48000,
                default: 48000,
                description: """
                Sample rate to decode at. Note: Opus is able to decode any stream
                at any supported sample rate. 48 kHz is recommended. For details,
                see https://tools.ietf.org/html/rfc7845#section-5.1 point 5.
                """
              ],
              channels: [
                spec: 1 | 2,
                default: 2,
                description: "Expected number of channels"
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    caps: [
      {RemoteStream, type: :packetized, content_format: one_of([Opus, nil])}
    ]

  def_output_pad :output, caps: {Raw, format: :s16le}

  @impl true
  def handle_init(%__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{native: nil})

    {:ok, state}
  end

  @impl true
  def handle_caps(:input, %Opus{channels: channels}, _ctx, state) do
    {caps, state} = maybe_make_native(channels, state)
    {{:ok, caps}, state}
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_demand(:output, size, :bytes, _ctx, state) do
    {{:ok, demand: {:input, div(size, @avg_opus_packet_size) + 1}}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    decoded = Native.decode_packet(state.native, buffer.payload)
    buffer = %Buffer{buffer | payload: decoded}
    {{:ok, buffer: {:output, buffer}}, state}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, state) do
    native = Native.create(state.sample_rate, state.channels)
    {:ok, %{state | native: native}}
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {:ok, %{state | native: nil}}
  end

  defp maybe_make_native(channels, %{channels: channels} = state) do
    {[], state}
  end

  defp maybe_make_native(channels, state) do
    native = Native.create(state.sample_rate, channels)
    caps = %Raw{format: :s16le, channels: channels, sample_rate: state.sample_rate}
    {[caps: {:output, caps}], %{state | native: native, channels: channels}}
  end
end
