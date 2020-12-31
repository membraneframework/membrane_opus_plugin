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

    {configuration_number, stereo_flag, frame_packing, data_without_toc} = parse_toc_byte(data)
    {_mode, _bandwidth, frame_duration} = parse_configuration(configuration_number)
    channels = parse_channels(stereo_flag)

    {frame_lengths, header_size} =
      FrameLengths.parse(frame_packing, data_without_toc, input_delimitation)

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

  @spec elapsed_time([non_neg_integer], pos_integer) :: Membrane.Time.non_neg_t()
  defp elapsed_time(frame_lengths, frame_duration) do
    # if a frame has length 0 it indicates a dropped frame and should not be
    # included in this calc
    present_frames = frame_lengths |> Enum.count(fn length -> length > 0 end)
    present_frames * frame_duration
  end

  @spec parse_data(binary, [non_neg_integer], pos_integer, map, boolean) :: {binary, boolean}
  defp parse_data(data, frame_lengths, header_size, state, self_delimiting?) do
    cond do
      self_delimiting? && state.delimitation == :undelimit ->
        {undelimit(data, frame_lengths, header_size), false}

      !self_delimiting? && state.delimitation == :delimit ->
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

  @spec parse_toc_byte(binary) ::
          {config_number :: 0..31, stereo_flag :: 0..1, frame_packing :: 0..3,
           rest_of_data :: binary}
  defp parse_toc_byte(data) do
    <<configuration_number::size(5), stereo_flag::size(1), frame_packing::size(2), rest::binary>> =
      data

    {configuration_number, stereo_flag, frame_packing, rest}
  end

  @spec parse_configuration(config_number :: 0..31) ::
          {mode :: :silk | :hybrid | :celt,
           bandwidth :: :narrow | :medium | :wide | :super_wide | :full,
           frame_duration :: Membrane.Time.non_neg_t()}
  defp parse_configuration(configuration_number) do
    case configuration_number do
      0 -> {:silk, :narrow, 10 |> milliseconds()}
      1 -> {:silk, :narrow, 20 |> milliseconds()}
      2 -> {:silk, :narrow, 40 |> milliseconds()}
      3 -> {:silk, :narrow, 60 |> milliseconds()}
      4 -> {:silk, :medium, 10 |> milliseconds()}
      5 -> {:silk, :medium, 20 |> milliseconds()}
      6 -> {:silk, :medium, 40 |> milliseconds()}
      7 -> {:silk, :medium, 60 |> milliseconds()}
      8 -> {:silk, :wide, 10 |> milliseconds()}
      9 -> {:silk, :wide, 20 |> milliseconds()}
      10 -> {:silk, :wide, 40 |> milliseconds()}
      11 -> {:silk, :wide, 60 |> milliseconds()}
      12 -> {:hybrid, :super_wide, 10 |> milliseconds()}
      13 -> {:hybrid, :super_wide, 20 |> milliseconds()}
      14 -> {:hybrid, :full, 10 |> milliseconds()}
      15 -> {:hybrid, :full, 20 |> milliseconds()}
      16 -> {:celt, :narrow, (2.5 * 1_000_000) |> trunc() |> nanoseconds()}
      17 -> {:celt, :narrow, 5 |> milliseconds()}
      18 -> {:celt, :narrow, 10 |> milliseconds()}
      19 -> {:celt, :narrow, 20 |> milliseconds()}
      20 -> {:celt, :wide, (2.5 * 1_000_000) |> trunc() |> nanoseconds()}
      21 -> {:celt, :wide, 5 |> milliseconds()}
      22 -> {:celt, :wide, 10 |> milliseconds()}
      23 -> {:celt, :wide, 20 |> milliseconds()}
      24 -> {:celt, :super_wide, (2.5 * 1_000_000) |> trunc() |> nanoseconds()}
      25 -> {:celt, :super_wide, 5 |> milliseconds()}
      26 -> {:celt, :super_wide, 10 |> milliseconds()}
      27 -> {:celt, :super_wide, 20 |> milliseconds()}
      28 -> {:celt, :full, (2.5 * 1_000_000) |> trunc() |> nanoseconds()}
      29 -> {:celt, :full, 5 |> milliseconds()}
      30 -> {:celt, :full, 10 |> milliseconds()}
      31 -> {:celt, :full, 20 |> milliseconds()}
    end
  end

  @spec parse_channels(0..1) :: channels :: 1..2
  defp parse_channels(stereo_flag) when stereo_flag in 0..1, do: stereo_flag + 1
end
