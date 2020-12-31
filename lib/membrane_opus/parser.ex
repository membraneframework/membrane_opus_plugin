defmodule Membrane.Opus.Parser do
  @moduledoc """
  Parses a raw incoming Opus stream and adds caps information, as well as metadata.

  Adds the following metadata:

  duration :: non_neg_integer()
    Number of nanoseconds encoded in this packet
  """

  use Membrane.Filter

  import Membrane.Time

  alias Membrane.{Buffer, Opus, RemoteStream}
  alias __MODULE__.FrameLengths

  def_options delimitation: [
                spec: :delimit | :undelimit | :keep,
                default: :keep,
                description: """
                If input is delimitted (as indicated by the `self_delimiting?`
                field in %Opus) and `:undelimit` is selected, will remove delimitting.

                If input is not delimitted and `:delimit` is selected, will add delimitting.

                If `:keep` is selected, will not change delimiting.

                Otherwise will raise.

                See https://tools.ietf.org/html/rfc6716#appendix-B for details
                on the self-delimitting Opus format.
                """
              ],
              input_delimitted?: [
                spec: boolean(),
                default: false,
                description: """
                If you know that the input is self-delimitted but you're reading from
                some element that isn't sending the correct structure, you can set this
                to true to force the Parser to assume the input is self-delimitted.
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
      Map.get(ctx.pads.input, :caps) || %{} |> Map.get(:self_delimiting?, state.input_delimitted?)

    {configuration_number, stereo_flag, frame_packing, data_without_toc} = parse_toc_byte(data)
    {_mode, _bandwidth, frame_duration} = parse_configuration(configuration_number)
    channels = parse_channels(stereo_flag)

    {frame_lengths, header_size} =
      FrameLengths.parse_frame_lengths(frame_packing, data_without_toc, input_delimitation)

    {parsed_data, self_delimiting?} =
      parse_data(data, frame_lengths, header_size, state, input_delimitation)

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

  @spec elapsed_time([non_neg_integer], pos_integer) :: non_neg_integer
  defp elapsed_time(frame_lengths, frame_duration) do
    # if a frame has length 0 it indicates a dropped frame and should not be
    # included in this calc
    present_frames =
      frame_lengths
      |> Enum.count(fn length -> length > 0 end)

    # we need to convert to nanoseconds ourselves because Membrane.Time
    # can't do conversions with floats and 2.5ms is a possible frame duration
    (present_frames * frame_duration * 1_000_000) |> trunc() |> nanoseconds()
  end

  @spec parse_data(binary, [non_neg_integer], pos_integer, map, boolean) :: {binary, boolean}
  defp parse_data(data, frame_lengths, header_size, state, self_delimiting?) do
    cond do
      state.delimitation == :keep ->
        {data, self_delimiting?}

      self_delimiting? && state.delimitation == :undelimit ->
        {undelimit(data, frame_lengths, header_size), false}

      !self_delimiting? && state.delimitation == :delimit ->
        {delimit(data, frame_lengths, header_size), true}

      true ->
        raise """
        Invalid delimitation option for #{__MODULE__}:
        Input caps delimitiation: #{self_delimiting?}
        Requested delimitation: #{state.delimitation}
        """
    end
  end

  @spec delimit(binary, [non_neg_integer], pos_integer) :: binary
  defp delimit(data, frame_lengths, header_size) do
    <<head::binary-size(header_size), body::binary>> = data

    [
      head,
      frame_lengths |> List.last() |> FrameLengths.encode_frame_length(),
      body
    ]
    |> :binary.list_to_bin()
  end

  @spec undelimit(binary, [non_neg_integer], pos_integer) :: binary
  defp undelimit(data, frame_lengths, header_size) do
    last_length = frame_lengths |> List.last() |> FrameLengths.encode_frame_length()
    last_length_size = byte_size(last_length)
    parsed_header_size = header_size - last_length_size

    <<parsed_head::binary-size(parsed_header_size), _last_length::binary-size(last_length_size),
      body::binary>> = data

    [
      parsed_head,
      body
    ]
    |> :binary.list_to_bin()
  end

  # parses config number, stereo flag, and frame packing strategy from the TOC
  # byte
  @spec parse_toc_byte(binary) :: {0..31, 0..1, 0..3, binary}
  defp parse_toc_byte(data) do
    <<configuration_number::size(5), stereo_flag::size(1), frame_packing::size(2), rest::binary>> =
      data

    {configuration_number, stereo_flag, frame_packing, rest}
  end

  # parses configuration values from TOC configuration number
  @spec parse_configuration(0..31) ::
          {:silk | :hybrid | :celt, :narrow | :medium | :wide | :super_wide | :full,
           float | 5 | 10 | 20 | 40 | 60}
  defp parse_configuration(configuration_number) do
    case configuration_number do
      0 -> {:silk, :narrow, 10}
      1 -> {:silk, :narrow, 20}
      2 -> {:silk, :narrow, 40}
      3 -> {:silk, :narrow, 60}
      4 -> {:silk, :medium, 10}
      5 -> {:silk, :medium, 20}
      6 -> {:silk, :medium, 40}
      7 -> {:silk, :medium, 60}
      8 -> {:silk, :wide, 10}
      9 -> {:silk, :wide, 20}
      10 -> {:silk, :wide, 40}
      11 -> {:silk, :wide, 60}
      12 -> {:hybrid, :super_wide, 10}
      13 -> {:hybrid, :super_wide, 20}
      14 -> {:hybrid, :full, 10}
      15 -> {:hybrid, :full, 20}
      16 -> {:celt, :narrow, 2.5}
      17 -> {:celt, :narrow, 5}
      18 -> {:celt, :narrow, 10}
      19 -> {:celt, :narrow, 20}
      20 -> {:celt, :wide, 2.5}
      21 -> {:celt, :wide, 5}
      22 -> {:celt, :wide, 10}
      23 -> {:celt, :wide, 20}
      24 -> {:celt, :super_wide, 2.5}
      25 -> {:celt, :super_wide, 5}
      26 -> {:celt, :super_wide, 10}
      27 -> {:celt, :super_wide, 20}
      28 -> {:celt, :full, 2.5}
      29 -> {:celt, :full, 5}
      30 -> {:celt, :full, 10}
      31 -> {:celt, :full, 20}
    end
  end

  # determines number of channels
  @spec parse_channels(0..1) :: 1..2
  defp parse_channels(stereo_flag) when stereo_flag in 0..1, do: stereo_flag + 1
end
