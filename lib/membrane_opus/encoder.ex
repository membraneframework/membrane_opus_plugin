defmodule Membrane.Opus.Encoder do
  @moduledoc """
  This element performs encoding of Opus audio into a raw stream. You'll need to parse the stream and then package it into a container in order to use it.
  """

  use Membrane.Filter

  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Opus
  alias Membrane.RawAudio

  @allowed_channels [1, 2]
  @allowed_applications [:voip, :audio, :low_delay]
  @allowed_sample_rates [8000, 12_000, 16_000, 24_000, 48_000]

  @type allowed_channels :: unquote(Bunch.Typespec.enum_to_alternative(@allowed_channels))
  @type allowed_applications :: unquote(Bunch.Typespec.enum_to_alternative(@allowed_applications))
  @type allowed_sample_rates :: unquote(Bunch.Typespec.enum_to_alternative(@allowed_sample_rates))

  def_options application: [
                spec: allowed_applications(),
                default: :audio,
                description: """
                Output type (similar to compression amount).

                See https://opus-codec.org/docs/opus_api-1.3.1/group__opus__encoder.html#gaa89264fd93c9da70362a0c9b96b9ca88.
                """
              ],
              input_stream_format: [
                spec: RawAudio.t(),
                type: :stream_format,
                default: nil,
                description: """
                Input type - used to set input sample rate and channels.
                """
              ]

  def_input_pad :input,
    accepted_format:
      any_of(
        %RawAudio{
          sample_format: :s16le,
          channels: channels,
          sample_rate: sample_rate
        }
        when channels in @allowed_channels and sample_rate in @allowed_sample_rates,
        Membrane.RemoteStream
      )

  def_output_pad :output, accepted_format: %Opus{self_delimiting?: false}

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        pts: nil,
        native: nil,
        queue: <<>>
      })

    {[], state}
  end

  @impl true
  def handle_setup(_ctx, state) when not is_nil(state.input_stream_format) do
    {[], %{state | native: mk_native!(state)}}
  end

  @impl true
  def handle_setup(_ctx, state), do: {[], state}

  @impl true
  def handle_playing(_ctx, %{input_stream_format: stream_format} = state)
      when not is_nil(stream_format) do
    output_stream_format = %Opus{channels: stream_format.channels}
    {[stream_format: {:output, output_stream_format}], state}
  end

  @impl true
  def handle_playing(_ctx, state), do: {[], state}

  @impl true
  def handle_stream_format(
        :input,
        %RawAudio{} = stream_format,
        _ctx,
        %{input_stream_format: nil} = state
      ) do
    state = %{state | input_stream_format: stream_format}
    native = mk_native!(state)
    output_stream_format = %Opus{channels: stream_format.channels}

    {[stream_format: {:output, output_stream_format}], %{state | native: native}}
  end

  @impl true
  def handle_stream_format(
        :input,
        %Membrane.RemoteStream{} = _stream_format,
        _ctx,
        %{input_stream_format: nil} = _state
      ) do
    raise """
    You need to specify `input_stream_format` in options if `Membrane.RemoteStream` will be received on the `:input` pad
    """
  end

  @impl true
  def handle_stream_format(
        :input,
        stream_format,
        _ctx,
        %{input_stream_format: stream_format} = state
      ) do
    {[], state}
  end

  @impl true
  def handle_stream_format(:input, %Membrane.RemoteStream{} = _stream_format, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, _state) do
    raise """
    Changing input sample rate or channels is not supported
    """
  end

  @impl true
  def handle_buffer(:input, %Buffer{payload: data, pts: pts}, _ctx, state) do
    case encode_buffer(state.queue <> data, %{state | pts: pts}, frame_size_in_bytes(state)) do
      {:ok, {[], rest}, new_state} ->
        # nothing was encoded
        {[], %{state | queue: rest, pts: new_state.pts}}

      {:ok, {encoded_buffers, rest}, new_state} ->
        # something was encoded
        IO.inspect(encoded_buffers, label: "encoded_buffers")
        {[buffer: {:output, encoded_buffers}], %{state | queue: rest, pts: new_state.pts }}
    end
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
      {buffer_actions ++ actions, %{state | queue: <<>>}}
    else
      {actions, %{state | queue: <<>>}}
    end
  end

  defp mk_native!(state) do
    with {:ok, channels} <- validate_channels(state.input_stream_format.channels),
         {:ok, input_rate} <- validate_sample_rate(state.input_stream_format.sample_rate),
         {:ok, application} <- map_application_to_value(state.application) do
      Native.create(input_rate, channels, application)
    else
      {:error, reason} ->
        raise "Failed to create encoder, reason: #{inspect(reason)}"
    end
  end

  defp map_application_to_value(application) do
    case application do
      :voip -> {:ok, 2048}
      :audio -> {:ok, 2049}
      :low_delay -> {:ok, 2051}
      _invalid -> {:error, "Invalid application"}
    end
  end

  defp validate_sample_rate(sample_rate) when sample_rate in @allowed_sample_rates do
    {:ok, sample_rate}
  end

  defp validate_sample_rate(_invalid_sr), do: {:error, "Invalid sample rate"}

  defp validate_channels(channels) when channels in @allowed_channels, do: {:ok, channels}
  defp validate_channels(_invalid_channels), do: {:error, "Invalid channels"}

  defp frame_size(state) do
    # 20 milliseconds
    div(state.input_stream_format.sample_rate, 1000) * 20
  end

  defp frame_size_in_bytes(state) do
    RawAudio.frames_to_bytes(frame_size(state), state.input_stream_format)
  end

  defp encode_buffer(raw_buffer, state, target_byte_size, encoded_frames \\ [])

  defp encode_buffer(raw_buffer, state, target_byte_size, encoded_frames)
       when byte_size(raw_buffer) >= target_byte_size do
    # Encode a single frame because buffer contains at least one frame

    <<raw_frame::binary-size(target_byte_size), rest::binary>> = raw_buffer
    {:ok, raw_encoded} = Native.encode_packet(state.native, raw_frame, frame_size(state))

    # maybe keep encoding if there are more frames
    out_buffer = [%Buffer{payload: raw_encoded, pts: state.pts} | encoded_frames]
    new_state = update_state_pts(state, raw_frame)

    encode_buffer(
      rest,
      new_state,
      target_byte_size,
      out_buffer
    )
  end

  defp encode_buffer(raw_buffer, state, _target_byte_size, encoded_frames) do
    # Invariant for encode_buffer - return what we have encoded
    {:ok, {encoded_frames |> Enum.reverse(), raw_buffer}, state}
  end

  defp update_state_pts(state, raw_frame) do
    if state.pts == nil do
      state
    else
      duration =
        raw_frame
        |> byte_size()
        |> RawAudio.bytes_to_time(state.input_stream_format)
      %{state | pts: state.pts + duration}
    end
  end
end
