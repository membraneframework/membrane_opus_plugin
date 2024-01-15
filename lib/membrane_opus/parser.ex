defmodule Membrane.Opus.Parser do
  @moduledoc """
  Parses a raw incoming Opus stream and adds stream_format information, as well as metadata.

  Adds the following metadata:

  duration :: non_neg_integer()
    Number of nanoseconds encoded in this packet
  """

  use Membrane.Filter

  alias __MODULE__.{Delimitation, FrameLengths}
  alias Membrane.{Buffer, Opus, RemoteStream}
  alias Membrane.Opus.Util

  @type delimitation_t :: :delimit | :undelimit | :keep

  def_options delimitation: [
                spec: delimitation_t(),
                default: :keep,
                description: """
                If input is delimitted? (as indicated by the `self_delimiting?`
                field in %Opus) and `:undelimit` is selected, will remove delimiting.

                If input is not delimitted? and `:delimit` is selected, will add delimiting.

                If `:keep` is selected, will not change delimiting.

                Otherwise will act like `:keep`.

                See https://tools.ietf.org/html/rfc6716#appendix-B for details
                on the self-delimiting Opus format.
                """
              ],
              input_delimitted?: [
                spec: boolean(),
                default: false,
                description: """
                If you know that the input is self-delimitted? but you're reading from
                some element that isn't sending the correct structure, you can set this
                to true to force the Parser to assume the input is self-delimitted? and
                ignore upstream stream_format information on self-delimitation.
                """
              ],
              generate_best_effort_timestamps?: [
                spec: boolean(),
                default: false,
                description: """
                If this is set to true parser will try to generate timestamps
                starting from 0 and increasing them by frame duration,
                otherwise it will pass pts from input to output, even if it's nil.
                """
              ]

  def_input_pad :input,
    accepted_format:
      any_of(Opus, %RemoteStream{content_format: format} when format in [Opus, nil])

  def_output_pad :output, accepted_format: Opus

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        pts_current: nil,
        queue: <<>>
      })

    {[], state}
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, state) do
    # ignore stream_formats, they will be sent in handle_buffer
    {[], state}
  defp set_current_pts(%{generate_best_effort_timestamps?: true, pts_current: nil} = state, _input_pts) do
    %{state | pts_current: 0}
  end

  defp set_current_pts(%{generate_best_effort_timestamps?: false, queue: <<>>} = state, input_pts) do
    %{state | pts_current: input_pts}
  end

  defp set_current_pts(state, _input_pts), do: state

  @impl true
  def handle_buffer(:input, %Buffer{payload: data, pts: input_pts}, ctx, state) do
    {delimitation_processor, self_delimiting?} =
      Delimitation.get_processor(state.delimitation, state.input_delimitted?)

check_pts_integrity? = state.queue != <<>> and not state.generate_best_effort_timestamps?

    case maybe_parse(
           state.queue <> data,
           delimitation_processor,
           set_current_pts(state, input_pts)
         ) do
      {:ok, queue, packets, channels, state} ->
        check_pts_integrity(check_pts_integrity_flag, List.first(packets), input_pts)

        stream_format = %Opus{
          self_delimiting?: self_delimiting?,
          channels: channels
        }

        packets_len = length(packets)

        packet_actions =
          cond do
            packets_len > 0 and stream_format != ctx.pads.output.stream_format ->
              [stream_format: {:output, stream_format}, buffer: {:output, packets}]

            packets_len > 0 ->
              [buffer: {:output, packets}]

            true ->
              []
          end

        {packet_actions, %{state | queue: queue}}

      :error ->
        {{:error, "An error occured in parsing"}, state}
    end
  end

  defp check_pts_integrity(true = _flag, %Buffer{pts: pts}, input_pts) do
    if pts != input_pts do
      raise """
      PTS values are not continuous
      """
    end
  end

  defp check_pts_integrity(false = _flag, %Buffer{pts: _pts}, _input_pts) do
  end

  defp maybe_parse(
         data,
         processor,
         packets \\ [],
         channels \\ 0,
         state
       )

  defp maybe_parse(
         data,
         processor,
         packets,
         channels,
         state
       )
       when byte_size(data) > 0 do
    with {:ok, configuration_number, stereo_flag, frame_packing} <- Util.parse_toc_byte(data),
         channels <- max(channels, Util.parse_channels(stereo_flag)),
         {:ok, _mode, _bandwidth, frame_duration} <-
           Util.parse_configuration(configuration_number),
         {:ok, header_size, frame_lengths, padding_size} <-
           FrameLengths.parse(frame_packing, data, state.input_delimitted?),
         expected_packet_size <- header_size + Enum.sum(frame_lengths) + padding_size,
         {:ok, raw_packet, rest} <- rest_of_packet(data, expected_packet_size) do
      duration = elapsed_time(frame_lengths, frame_duration)

      packet = %Buffer{
        pts: state.pts_current,
        payload: processor.process(raw_packet, frame_lengths, header_size),
        metadata: %{
          duration: duration
        }
      }

      updated_state =
        if state.pts_current == nil do
          state
        else
          %{state | pts_current: state.pts_current + duration}
        end

      maybe_parse(
        rest,
        processor,
        [packet | packets],
        channels,
        updated_state
      )
    else
      {:error, :cont} ->
        {:ok, data, packets |> Enum.reverse(), channels, state}

      :error ->
        :error
    end
  end

  defp maybe_parse(
         data,
         _processor,
         packets,
         channels,
         state
       ) do
    {:ok, data, packets |> Enum.reverse(), channels, state}
  end

  @spec rest_of_packet(data :: binary, expected_packet_size :: pos_integer) ::
          {:ok, raw_packet :: binary, rest :: binary} | {:error, :cont}
  defp rest_of_packet(data, expected_packet_size) do
    case data do
      <<raw_packet::binary-size(expected_packet_size), rest::binary>> ->
        {:ok, raw_packet, rest}

      _otherwise ->
        {:error, :cont}
    end
  end

  @spec elapsed_time(frame_lengths :: [non_neg_integer], frame_duration :: pos_integer) ::
          elapsed_time :: Membrane.Time.non_neg()
  defp elapsed_time(frame_lengths, frame_duration) do
    # if a frame has length 0 it indicates a dropped frame and should not be
    # included in this calc
    present_frames = frame_lengths |> Enum.count(fn length -> length > 0 end)
    present_frames * frame_duration
  end
end
