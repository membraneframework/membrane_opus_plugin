defmodule Membrane.Opus.Parser do
  @moduledoc """
  Parses a raw incoming Opus stream and adds caps information, as well as metadata.

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
                ignore upstream caps information on self-delimitation.
                """
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: [
      Opus,
      {RemoteStream, type: :bytestream, content_format: one_of([Opus, nil])}
    ]

  def_output_pad :output, caps: Opus, demand_mode: :auto

  @impl true
  def handle_init(%__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        pts: 0,
        buffer: <<>>
      })

    {:ok, state}
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    # ignore caps, they will be sent in handle_process
    {:ok, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: data}, ctx, state) do
    {delimitation_processor, self_delimiting?} =
      Delimitation.get_processor(state.delimitation, state.input_delimitted?)

    case maybe_parse(
           state.buffer <> data,
           state.pts,
           state.input_delimitted?,
           delimitation_processor
         ) do
      {:ok, buffer, pts, packets, channels} ->
        caps = %Opus{
          self_delimiting?: self_delimiting?,
          channels: channels
        }

        packets_len = length(packets)

        packet_actions =
          cond do
            packets_len > 0 and caps != ctx.pads.output.caps ->
              [caps: {:output, caps}, buffer: {:output, packets}]

            packets_len > 0 ->
              [buffer: {:output, packets}]

            true ->
              []
          end

        {{:ok, packet_actions}, %{state | buffer: buffer, pts: pts}}

      :error ->
        {{:error, "An error occured in parsing"}, state}
    end
  end

  @spec maybe_parse(
          data :: binary,
          pts :: Membrane.Time.t(),
          input_delimitted? :: boolean,
          processor :: Delimitation.processor_t(),
          packets :: [Buffer.t()],
          channels :: 0..2
        ) :: {:ok, remaining_buffer :: binary, packets :: [Buffer.t()], channels :: 0..2} | :error
  defp maybe_parse(data, pts, input_delimitted?, processor, packets \\ [], channels \\ 0)

  defp maybe_parse(data, pts, input_delimitted?, processor, packets, channels)
       when byte_size(data) > 0 do
    with {:ok, configuration_number, stereo_flag, frame_packing} <- Util.parse_toc_byte(data),
         channels <- max(channels, Util.parse_channels(stereo_flag)),
         {:ok, _mode, _bandwidth, frame_duration} <-
           Util.parse_configuration(configuration_number),
         {:ok, header_size, frame_lengths, padding_size} <-
           FrameLengths.parse(frame_packing, data, input_delimitted?),
         expected_packet_size <- header_size + Enum.sum(frame_lengths) + padding_size,
         {:ok, raw_packet, rest} <- rest_of_packet(data, expected_packet_size) do
      duration = elapsed_time(frame_lengths, frame_duration)

      packet = %Buffer{
        pts: pts,
        payload: processor.process(raw_packet, frame_lengths, header_size),
        metadata: %{
          duration: duration
        }
      }

      maybe_parse(
        rest,
        pts + duration,
        input_delimitted?,
        processor,
        [packet | packets],
        channels
      )
    else
      {:error, :cont} ->
        {:ok, data, pts, packets |> Enum.reverse(), channels}

      :error ->
        :error
    end
  end

  defp maybe_parse(data, pts, _input_delimitted?, _processor, packets, channels) do
    {:ok, data, pts, packets |> Enum.reverse(), channels}
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
          elapsed_time :: Membrane.Time.non_neg_t()
  defp elapsed_time(frame_lengths, frame_duration) do
    # if a frame has length 0 it indicates a dropped frame and should not be
    # included in this calc
    present_frames = frame_lengths |> Enum.count(fn length -> length > 0 end)
    present_frames * frame_duration
  end
end
