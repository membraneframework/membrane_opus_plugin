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
  alias Membrane.Opus

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
  def_output_pad :output, caps: {Opus, self_delimiting?: false}

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
  def handle_stopped_to_prepared(_ctx, state) do
    case state |> mk_native do
      {:ok, native} ->
        {:ok, %{state | native: native}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  @impl true
  def handle_caps(:input, caps, _ctx, %{input_caps: nil} = state) do
    output_caps = %Opus{channels: caps.channels}
    {{:ok, caps: {:output, output_caps}}, %{state | input_caps: caps}}
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

    case encode_buffer(to_encode, state, frame_size_in_bytes(state)) do
      {:ok, {[], rest}} ->
        # nothing was encoded
        {{:ok, redemand: :output}, %{state | queue: rest}}

      {:ok, {encoded_buffers, rest}} ->
        # something was encoded
        {{:ok, buffer: {:output, encoded_buffers}}, %{state | queue: rest}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {:ok, %{state | native: nil}}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    actions = [end_of_stream: :output]

    if byte_size(state.queue) > 0 do
      # opus must receive input that is exactly the frame_size, so we need to
      # pad with 0
      to_encode = String.pad_trailing(state.queue, frame_size_in_bytes(state), <<0>>)
      {:ok, raw_encoded} = Native.encode_packet(state.native, to_encode, frame_size(state))
      buffer_actions = [buffer: {:output, %Buffer{payload: raw_encoded}}]
      {{:ok, buffer_actions ++ actions}, %{state | queue: <<>>}}
    else
      {{:ok, actions}, %{state | queue: <<>>}}
    end
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
    div(state.input_caps.sample_rate, 1000) * 20
  end

  defp frame_size_in_bytes(state) do
    Raw.frames_to_bytes(frame_size(state), state.input_caps)
  end

  defp encode_buffer(raw_buffer, state, target_byte_size, encoded_frames \\ [])

  defp encode_buffer(raw_buffer, state, target_byte_size, encoded_frames)
       when byte_size(raw_buffer) >= target_byte_size do
    # Encode a single frame because buffer contains at least one frame
    <<raw_frame::binary-size(target_byte_size), rest::binary>> = raw_buffer
    {:ok, raw_encoded} = Native.encode_packet(state.native, raw_frame, frame_size(state))

    # maybe keep encoding if there are more frames
    encode_buffer(
      rest,
      state,
      target_byte_size,
      [%Buffer{payload: raw_encoded} | encoded_frames]
    )
  end

  defp encode_buffer(raw_buffer, _state, _target_byte_size, encoded_frames) do
    # Invariant for encode_buffer - return what we have encoded
    {:ok, {encoded_frames |> Enum.reverse(), raw_buffer}}
  end
end
