defmodule Membrane.Opus.Decoder do
  @moduledoc """
  This element performs decoding of Opus audio.
  """

  use Membrane.Filter

  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.{Buffer, Opus, RemoteStream}
  alias Membrane.Opus.Util
  alias Membrane.RawAudio

  def_options sample_rate: [
                spec: 8_000 | 12_000 | 16_000 | 24_000 | 48_000,
                default: 48_000,
                description: """
                Sample rate to decode at. Note: Opus is able to decode any stream
                at any supported sample rate. 48 kHz is recommended. For details,
                see https://tools.ietf.org/html/rfc7845#section-5.1 point 5.
                """
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    demand_mode: :auto,
    accepted_format:
      any_of(
        %Opus{self_delimiting?: false},
        %RemoteStream{type: :packetized, content_format: format} when format in [Opus, nil]
      )

  def_output_pad :output, accepted_format: %RawAudio{sample_format: :s16le}, demand_mode: :auto

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{native: nil, channels: nil})

    {[], state}
  end

  @impl true
  def handle_stream_format(:input, %Opus{channels: channels}, _ctx, state) do
    maybe_make_native(channels, state)
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    if buffer.payload === "" do
      Membrane.Logger.warn("Payload is empty.")
      {[], state}
    else
      {:ok, _config_number, stereo_flag, _frame_packing} = Util.parse_toc_byte(buffer.payload)
      channels = Util.parse_channels(stereo_flag)
      {stream_format, state} = maybe_make_native(channels, state)

      decoded = Native.decode_packet(state.native, buffer.payload)
      buffer = %Buffer{buffer | payload: decoded}
      {stream_format ++ [buffer: {:output, buffer}], state}
    end
  end

  defp maybe_make_native(channels, %{channels: channels} = state) do
    {[], state}
  end

  defp maybe_make_native(channels, state) do
    native = Native.create(state.sample_rate, channels)

    stream_format = %RawAudio{
      sample_format: :s16le,
      channels: channels,
      sample_rate: state.sample_rate
    }

    {[stream_format: {:output, stream_format}], %{state | native: native, channels: channels}}
  end
end
