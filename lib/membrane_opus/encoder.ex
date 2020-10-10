defmodule Membrane.Opus.Encoder do
  @moduledoc """
  This element performs encoding of Opus audio.
  """

  use Membrane.Filter
  use Bunch.Typespec

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Caps.Matcher
  alias Membrane.Opus

  @list_type allowed_channels :: [1, 2]
  @default_channels 2

  @list_type allowed_applications :: [:voip, :audio, :low_delay]
  @default_application :audio

  @list_type allowed_sample_rates :: [8000, 12_000, 16_000, 24_000, 48_000]

  @supported_input {Raw,
                    format: :s16le,
                    channels: :any,
                    sample_rate: Matcher.one_of(@allowed_sample_rates)}

  def_options application: [
                spec: allowed_applications(),
                default: @default_application,
                description: """
                Output type (similar to compression amount). See https://opus-codec.org/docs/opus_api-1.3.1/group__opus__encoder.html#gaa89264fd93c9da70362a0c9b96b9ca88.
                """
              ],
              channels: [
                spec: allowed_channels(),
                default: @default_channels,
                description: "Desired number of channels"
              ],
              input_caps: [
                spec: Raw.t(),
                type: :caps,
                default: nil,
                description: "Input type - used to set input sample rate"
              ]

  def_input_pad :input, demand_unit: :bytes, caps: @supported_input
  def_output_pad :output, caps: Opus

  @impl true
  def handle_init(%__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        native: nil,
        frame_size: frame_size(options)
      })

    {:ok, state}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, state) do
    inject_native(state)
  end

  @impl true
  def handle_caps(:input, caps, _ctx, %{input_caps: input_caps} = state)
      when input_caps in [nil, caps] do
    inject_native(state)
  end

  @impl true
  def handle_caps(:input, caps, _ctx, %{input_caps: stored_caps}) do
    raise """
    Received caps #{inspect(caps)} are different than defined in options #{inspect(stored_caps)}.
    """
  end

  @impl true
  def handle_demand(:output, size, :bytes, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size * Map.get(state, :frame_size)}}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    {:ok, encoded} = Native.encode_packet(state.native, buffer.payload)
    buffer = %Buffer{buffer | payload: encoded}
    {{:ok, buffer: {:output, buffer}}, state}
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    :ok = Native.destroy(state.native)
    {:ok, state}
  end

  defp inject_native(state) do
    with {:ok, native} <-
           mk_native(
             Map.get(state, :input_caps).sample_rate,
             Map.get(state, :channels),
             Map.get(state, :application),
             Map.get(state, :frame_size)
           ) do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp mk_native(input_rate, channels, application, frame_size) do
    with {:ok, channels} <- validate_channels(channels),
         {:ok, input_rate} <- validate_sample_rate(input_rate),
         {:ok, application} <- map_application_to_value(application),
         native <-
           Native.create(input_rate, channels, application, frame_size) do
      {:ok, native}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp map_application_to_value(:voip) do
    {:ok, 2048}
  end

  defp map_application_to_value(:audio) do
    {:ok, 2049}
  end

  defp map_application_to_value(:low_delay) do
    {:ok, 2051}
  end

  defp map_application_to_value(_) do
    {:error, :invalid_application}
  end

  defp validate_sample_rate(sample_rate) when sample_rate in @allowed_sample_rates do
    {:ok, sample_rate}
  end

  defp validate_sample_rate(_) do
    {:error, :invalid_sample_rate}
  end

  defp validate_channels(channels) when channels in @allowed_channels do
    {:ok, channels}
  end

  defp validate_channels(_) do
    {:error, :invalid_channels}
  end

  defp frame_size(options) do
    round(Map.get(options, :input_caps).sample_rate * 20 / 1000 / Map.get(options, :channels))
  end
end
