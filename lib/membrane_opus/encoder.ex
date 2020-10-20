defmodule Membrane.Opus.Encoder do
  @moduledoc """
  This element performs encoding of Opus audio into a raw stream. You'll need to parse the stream and then package it into a container in order to use it.
  """

  use Membrane.Filter
  use Bunch.Typespec

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Caps.Matcher

  @list_type allowed_channels :: [1, 2]

  @list_type allowed_applications :: [:voip, :audio, :low_delay]
  @default_application :audio

  @list_type allowed_sample_rates :: [8000, 12_000, 16_000, 24_000, 48_000]

  @supported_input {Raw,
                    format: :s16le,
                    channels: Matcher.one_of(@allowed_channels),
                    sample_rate: Matcher.one_of(@allowed_sample_rates)}

  def_options application: [
                spec: allowed_applications(),
                default: @default_application,
                description: """
                Output type (similar to compression amount). See https://opus-codec.org/docs/opus_api-1.3.1/group__opus__encoder.html#gaa89264fd93c9da70362a0c9b96b9ca88.
                """
              ],
              input_caps: [
                spec: Raw.t(),
                type: :caps,
                default: nil,
                description: """
                Input type - used to set input sample rate and channels
                """
              ]

  def_input_pad :input, demand_unit: :bytes, caps: @supported_input
  def_output_pad :output, caps: :any

  @impl true
  def handle_init(%__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        native: nil,
        queue: <<>>
      })

    {:ok, state}
  end

  @impl true
  def handle_start_of_stream(:input, _ctx, state) do
    case state |> mk_native do
      {:ok, native} ->
        {:ok, %{state | native: native}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, _state) do
    raise """
    Changing input sample rate or channels is not supported
    """
  end

  @impl true
  def handle_demand(:output, size, :bytes, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_demand(:output, bufs, :buffers, _ctx, state) do
    {{:ok, demand: {:input, frame_size_in_bytes(state) * bufs}}, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: data}, _ctx, state) do
    # holds a buffer of raw input that is not yet encoded
    to_encode = state.queue <> data

    with {:ok, {encoded_buffers, bytes_used}} when bytes_used > 0 <-
           encode_buffer(to_encode, state, frame_size_in_bytes(state)) do
      <<_handled::binary-size(bytes_used), rest::binary>> = to_encode
      {{:ok, buffer: {:output, encoded_buffers}}, %{state | queue: rest}}
    else
      {:ok, _} -> {{:ok, redemand: :output}, %{state | queue: to_encode}}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    :ok = Native.destroy(state.native)
    {:ok, state}
  end

  defp mk_native(state) do
    with {:ok, channels} <- validate_channels(state.input_caps.channels),
         {:ok, input_rate} <- validate_sample_rate(state.input_caps.sample_rate),
         {:ok, application} <- map_application_to_value(state.application),
         native <- Native.create(input_rate, channels, application) do
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

  defp frame_size(state) do
    # 20 milliseconds
    div(state.input_caps.sample_rate, 50)
  end

  defp frame_size_in_bytes(state) do
    Raw.frames_to_bytes(frame_size(state), state.input_caps)
  end

  defp encode_buffer(raw_buffer, state, target_byte_size, encoded_frames \\ [], bytes_used \\ 0)

  defp encode_buffer(raw_buffer, state, target_byte_size, encoded_frames, bytes_used)
       when byte_size(raw_buffer) >= target_byte_size do
    # Encode a single frame because buffer contains at least one frame
    <<raw_frame::binary-size(target_byte_size), rest::binary>> = raw_buffer
    {:ok, raw_encoded} = Native.encode_packet(state.native, raw_frame, frame_size(state))

    # maybe keep encoding if there are more frames
    encode_buffer(
      rest,
      state,
      target_byte_size,
      [%Buffer{payload: raw_encoded} | encoded_frames],
      bytes_used + target_byte_size
    )
  end

  defp encode_buffer(_raw_buffer, _state, _target_byte_size, encoded_frames, bytes_used) do
    # Invariant for encode_buffer - return what we have encoded
    {:ok, {encoded_frames |> Enum.reverse(), bytes_used}}
  end
end
