defmodule Membrane.Opus.Parser do
  @moduledoc """
  Parses a raw incoming Opus stream and adds caps information, as well as metadata.

  Adds the following metadata:

  duration :: non_neg_integer()
    Number of nanoseconds encoded in this packet
  """

  use Membrane.Filter

  alias Membrane.{Buffer, Opus, RemoteStream}
  alias Membrane.Opus.Util
  alias __MODULE__.FrameLengths

  @type delimitation_t :: :delimit | :undelimit | :keep

  def_options delimitation: [
                spec: delimitation_t,
                default: :keep,
                description: """
                If input is delimited (as indicated by the `self_delimiting?`
                field in %Opus) and `:undelimit` is selected, will remove delimiting.

                If input is not delimited and `:delimit` is selected, will add delimiting.

                If `:keep` is selected, will not change delimiting.

                Otherwise will act like `:keep`.

                See https://tools.ietf.org/html/rfc6716#appendix-B for details
                on the self-delimiting Opus format.
                """
              ],
              input_delimited?: [
                spec: boolean(),
                default: false,
                description: """
                If you know that the input is self-delimited but you're reading from
                some element that isn't sending the correct structure, you can set this
                to true to force the Parser to assume the input is self-delimited.
                """
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    caps: [
      Opus,
      {RemoteStream, type: :packetized, content_format: one_of([Opus, nil])}
    ]

  def_output_pad :output, caps: Opus

  @impl true
  def handle_init(%__MODULE__{} = options) do
    {:ok, options |> Map.from_struct()}
  end

  @impl true
  def handle_demand(:output, bufs, :buffers, _ctx, state) do
    {{:ok, demand: {:input, bufs}}, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: data}, ctx, state) do
    input_delimitation =
      Map.get(ctx.pads.input, :caps) || %{} |> Map.get(:self_delimiting?, state.input_delimited?)

    {configuration_number, stereo_flag, frame_packing, data_without_toc} =
      Util.parse_toc_byte(data)

    {_mode, _bandwidth, frame_duration} = Util.parse_configuration(configuration_number)
    channels = Util.parse_channels(stereo_flag)

    {frame_lengths, header_size} =
      FrameLengths.parse(frame_packing, data_without_toc, input_delimitation)

    {parsed_data, self_delimiting?} =
      parse_data(data, frame_lengths, header_size, state.delimitation, input_delimitation)

    caps = %Opus{
      channels: channels,
      self_delimiting?: self_delimiting?
    }

    buffer = %Buffer{
      payload: parsed_data,
      metadata: %{
        duration: elapsed_time(frame_lengths, frame_duration)
      }
    }

    {{:ok, caps: {:output, caps}, buffer: {:output, buffer}}, state}
  end

  @spec elapsed_time([non_neg_integer], pos_integer) :: Membrane.Time.non_neg_t()
  defp elapsed_time(frame_lengths, frame_duration) do
    # if a frame has length 0 it indicates a dropped frame and should not be
    # included in this calc
    present_frames = frame_lengths |> Enum.count(fn length -> length > 0 end)
    present_frames * frame_duration
  end

  @spec parse_data(binary, [non_neg_integer], pos_integer, delimitation_t, boolean) ::
          {binary, boolean}
  defp parse_data(data, frame_lengths, header_size, delimitation, self_delimiting?) do
    cond do
      self_delimiting? && delimitation == :undelimit ->
        {undelimit(data, frame_lengths, header_size), false}

      !self_delimiting? && delimitation == :delimit ->
        {delimit(data, frame_lengths, header_size), true}

      true ->
        {data, self_delimiting?}
    end
  end

  @spec delimit(binary, [non_neg_integer], pos_integer) :: binary
  defp delimit(data, frame_lengths, header_size) do
    <<head::binary-size(header_size), body::binary>> = data
    <<head::binary, frame_lengths |> List.last() |> FrameLengths.encode()::binary, body::binary>>
  end

  @spec undelimit(binary, [non_neg_integer], pos_integer) :: binary
  defp undelimit(data, frame_lengths, header_size) do
    last_length = frame_lengths |> List.last() |> FrameLengths.encode()
    last_length_size = byte_size(last_length)
    parsed_header_size = header_size - last_length_size

    <<parsed_head::binary-size(parsed_header_size), _last_length::binary-size(last_length_size),
      body::binary>> = data

    <<parsed_head::binary, body::binary>>
  end
end
