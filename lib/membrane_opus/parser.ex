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
  @dialyzer {:nowarn_function, maybe_parse: 5}

  def_options delimitation: [
                spec: delimitation_t(),
                default: :keep,
                description: """
                If input is self-delimiting and `:undelimit` is selected, delimiting will be removed.

                If input is not self-delimiting and `:delimit` is selected, delimiting will be added.

                If `:keep` is selected, delimiting will stay unchanged.

                See https://tools.ietf.org/html/rfc6716#appendix-B for details
                on the self-delimiting Opus format.
                """
              ],
              # Remote
              # Opus undel
              # Opus del
              assume_input_self_delimiting?: [
                spec: boolean(),
                default: false,
                description: """
                If an input stream format is a `Membrane.RemoteStream`, then the
                delimitation provided with this option will be assumed.
                If it's `Membrane.Opus`, then this option will be ignored.
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

  defmodule State do
    @moduledoc false

    alias Membrane.Opus.Parser

    @type t :: %__MODULE__{
            delimitation: Parser.delimitation_t(),
            assume_input_self_delimiting?: boolean(),
            generate_best_effort_timestamps?: boolean(),
            current_pts: Membrane.Time.t() | nil,
            queue: binary(),
            input_self_delimiting?: boolean()
          }

    @enforce_keys [
      :delimitation,
      :assume_input_self_delimiting?,
      :generate_best_effort_timestamps?
    ]

    defstruct @enforce_keys ++
                [
                  current_pts: nil,
                  queue: <<>>,
                  input_self_delimiting?: false
                ]
  end

  @impl true
  def handle_init(_ctx, opts) do
    state = struct!(State, Map.from_struct(opts))

    {[], state}
  end

  @impl true
  def handle_stream_format(:input, %RemoteStream{}, _ctx, %State{} = state) do
    {[], %State{state | input_self_delimiting?: state.assume_input_self_delimiting?}}
  end

  @impl true
  def handle_stream_format(
        :input,
        %Opus{self_delimiting?: self_delimiting?},
        _ctx,
        %State{} = state
      ) do
    {[], %State{state | input_self_delimiting?: self_delimiting?}}
  end

  defp set_current_pts(
         %State{generate_best_effort_timestamps?: true, current_pts: nil} = state,
         _input_pts
       ) do
    %State{state | current_pts: 0}
  end

  defp set_current_pts(
         %State{generate_best_effort_timestamps?: false, queue: <<>>} = state,
         input_pts
       ) do
    %State{state | current_pts: input_pts}
  end

  defp set_current_pts(%State{} = state, _input_pts), do: state

  @impl true
  def handle_buffer(:input, %Buffer{payload: data, pts: input_pts}, ctx, %State{} = state) do
    {delimitation_processor, self_delimiting?} =
      Delimitation.get_processor(state.delimitation, state.input_self_delimiting?)

    check_pts_integrity? = state.queue != <<>> and not state.generate_best_effort_timestamps?

    {:ok, queue, packets, channels, %State{} = state} =
      maybe_parse(
        state.queue <> data,
        delimitation_processor,
        set_current_pts(state, input_pts)
      )

    packets_len = length(packets)

    if check_pts_integrity? and packets_len > 0 do
      Util.validate_pts_integrity(packets, input_pts)
    end

    stream_format = %Opus{
      self_delimiting?: self_delimiting?,
      channels: channels
    }

    packet_actions =
      cond do
        packets_len > 0 and stream_format != ctx.pads.output.stream_format ->
          [stream_format: {:output, stream_format}, buffer: {:output, packets}]

        packets_len > 0 ->
          [buffer: {:output, packets}]

        true ->
          []
      end

    {packet_actions, %State{state | queue: queue}}
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
         %State{} = state
       )
       when byte_size(data) > 0 do
    with {:ok, configuration_number, stereo_flag, frame_packing} <- Util.parse_toc_byte(data),
         channels <- max(channels, Util.parse_channels(stereo_flag)),
         {:ok, _mode, _bandwidth, frame_duration} <-
           Util.parse_configuration(configuration_number),
         {:ok, header_size, frame_lengths, padding_size} <-
           FrameLengths.parse(frame_packing, data, state.input_self_delimiting?),
         expected_packet_size <- header_size + Enum.sum(frame_lengths) + padding_size,
         {:ok, raw_packet, rest} <- rest_of_packet(data, expected_packet_size) do
      duration = packet_duration(frame_lengths, frame_duration)

      packet = %Buffer{
        pts: state.current_pts,
        payload: processor.process(raw_packet, frame_lengths, header_size),
        metadata: %{
          duration: duration
        }
      }

      state =
        if state.current_pts == nil do
          state
        else
          %State{state | current_pts: state.current_pts + duration}
        end

      maybe_parse(
        rest,
        processor,
        [packet | packets],
        channels,
        state
      )
    else
      :error ->
        raise "An error occured in parsing"

      {:error, :cont} ->
        {:ok, data, packets |> Enum.reverse(), channels, state}
    end
  end

  defp maybe_parse(
         data,
         _processor,
         packets,
         channels,
         %State{} = state
       ) do
    {:ok, data, packets |> Enum.reverse(), channels, state}
  end

  @spec rest_of_packet(data :: binary, expected_packet_size :: pos_integer) ::
          {:ok, raw_packet :: binary, rest :: binary} | {:error, :cont}
  defp rest_of_packet(data, expected_packet_size) do
    case data do
      <<raw_packet::binary-size(^expected_packet_size), rest::binary>> ->
        {:ok, raw_packet, rest}

      _otherwise ->
        {:error, :cont}
    end
  end

  @spec packet_duration(
          frame_lengths :: [non_neg_integer()],
          frame_duration :: Membrane.Time.non_neg()
        ) ::
          duration :: Membrane.Time.non_neg()
  defp packet_duration(frame_lengths, frame_duration) do
    length(frame_lengths) * frame_duration
  end
end
