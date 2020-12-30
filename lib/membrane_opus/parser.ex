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
      parse_frame_lengths(frame_packing, data_without_toc, input_delimitation)

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

  # handles self-delimiting
  defp delimit(data, frame_lengths, header_size) do
    <<head::binary-size(header_size), body::binary>> = data

    [
      head,
      frame_lengths |> List.last() |> encode_frame_length(),
      body
    ]
    |> :binary.list_to_bin()
  end

  defp undelimit(data, frame_lengths, header_size) do
    last_length = frame_lengths |> List.last() |> encode_frame_length()
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
  defp parse_toc_byte(data) do
    <<configuration_number::size(5), stereo_flag::size(1), frame_packing::size(2), rest::binary>> =
      data

    {configuration_number, stereo_flag, frame_packing, rest}
  end

  # parses configuration values from TOC configuration number
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
  defp parse_channels(stereo_flag) when stereo_flag in 0..1, do: stereo_flag + 1

  # returns ordered list of frame lengths and header length
  @spec parse_frame_lengths(non_neg_integer, binary, boolean) :: {[non_neg_integer], pos_integer}
  defp parse_frame_lengths(frame_packing, data_without_toc, self_delimiting?) do
    case frame_packing do
      # there is one frame in this packet
      0 ->
        code_zero_lengths(data_without_toc, self_delimiting?)

      # there are two equal-length frames in this packet
      1 ->
        code_one_lengths(data_without_toc, self_delimiting?)

      # there are two non-equal-length frames in this packet
      2 ->
        code_two_lengths(data_without_toc, self_delimiting?)

      # there are two or more frames of arbitrary size
      3 ->
        code_three_lengths(data_without_toc, self_delimiting?)
    end
  end

  defp code_zero_lengths(data_without_toc, self_delimiting?) do
    if self_delimiting? do
      {length, length_bytes} = calculate_frame_length(data_without_toc, 0)
      {[length], 1 + length_bytes}
    else
      {[byte_size(data_without_toc)], 1}
    end
  end

  defp code_one_lengths(data_without_toc, self_delimiting?) do
    if self_delimiting? do
      {length, length_bytes} = calculate_frame_length(data_without_toc, 0)
      {[length, length], 1 + length_bytes}
    else
      length = div(byte_size(data_without_toc), 2)
      {[length, length], 1}
    end
  end

  defp code_two_lengths(data_without_toc, self_delimiting?) do
    {first_len, first_bytes_used} = calculate_frame_length(data_without_toc, 0)

    if self_delimiting? do
      {second_len, second_bytes_used} = calculate_frame_length(data_without_toc, first_bytes_used)
      {[first_len, second_len], 1 + first_bytes_used + second_bytes_used}
    else
      {[first_len, byte_size(data_without_toc) - first_bytes_used - first_len],
       1 + first_bytes_used}
    end
  end

  # calculates frame lengths for Code 3 packets
  defp code_three_lengths(data_without_toc, self_delimiting?) do
    <<vbr_flag::size(1), padding_flag::size(1), frame_count::size(6), rest::binary>> =
      data_without_toc

    if vbr_flag == 1 do
      code_three_vbr_lengths(rest, padding_flag, frame_count, self_delimiting?)
    else
      code_three_cbr_lengths(rest, padding_flag, frame_count, self_delimiting?)
    end
  end

  defp code_three_vbr_lengths(data_without_headers, padding_flag, frame_count, self_delimiting?) do
    {padding_length, padding_encoding_length} =
      calculate_padding_info(padding_flag, data_without_headers)

    byte_offset = padding_encoding_length

    frames_with_lengths =
      if self_delimiting? do
        frame_count
      else
        # (frame_count - 1) frames have individual frame lengths that we need to
        # calculate, but the last frame's size is implied
        frame_count - 1
      end

    {lengths, byte_offset} =
      0..(frames_with_lengths - 1)
      |> Enum.map_reduce(byte_offset, fn _i, byte_offset ->
        {length, length_encoding_size} = calculate_frame_length(data_without_headers, byte_offset)
        {length, byte_offset + length_encoding_size}
      end)

    frame_lengths =
      if self_delimiting? do
        lengths
      else
        last_frame_length =
          byte_size(data_without_headers) - byte_offset - Enum.sum(lengths) - padding_length

        lengths ++ [last_frame_length]
      end

    # adding 2 for TOC and code three header
    {frame_lengths, 2 + byte_offset}
  end

  defp code_three_cbr_lengths(data_without_headers, padding_flag, frame_count, self_delimiting?) do
    {padding_length, padding_encoding_length} =
      calculate_padding_info(padding_flag, data_without_headers)

    {frame_duration, header_length} =
      if self_delimiting? do
        {frame_duration, bytes_used} =
          calculate_frame_length(data_without_headers, padding_encoding_length)

        # adding 2 for TOC and code three header
        {frame_duration, 2 + padding_encoding_length + bytes_used}
      else
        frame_duration =
          div(
            byte_size(data_without_headers) - padding_encoding_length - padding_length,
            frame_count
          )

        # adding 2 for TOC and code three header
        {frame_duration, 2 + padding_encoding_length}
      end

    frame_lengths =
      0..(frame_count - 1)
      |> Enum.map(fn _i -> frame_duration end)

    {frame_lengths, header_length}
  end

  # calculates frame length of the frame starting at byte_offset, specifically
  # for code 2 or 3 packets, and the number of bytes used to encode the frame
  # length
  defp calculate_frame_length(data, byte_offset) do
    <<_head::binary-size(byte_offset), length::size(8), _rest::binary>> = data

    if length < 252 do
      {length, 1}
    else
      <<_head::binary-size(byte_offset), _length::size(8), overflow_length::size(8),
        _rest::binary>> = data

      # https://tools.ietf.org/html/rfc6716#section-3.1
      {overflow_length * 4 + length, 2}
    end
  end

  # opposite of calculate_frame_length: given a length, encode it
  defp encode_frame_length(length) do
    if length < 252 do
      <<length::size(8)>>
    else
      <<252 + rem(length - 252, 4)::size(8), div(length - 252, 4)::size(8)>>
    end
  end

  # calculates total packet padding length, specifically for code 3 packets,
  # and the number of bytes used to encode the padding length
  defp calculate_padding_info(padding_flag, _data) when padding_flag == 0, do: {0, 0}

  defp calculate_padding_info(padding_flag, data) when padding_flag == 1 do
    do_calculate_padding_info(data)
  end

  defp do_calculate_padding_info(data, current_padding \\ 0, byte_offset \\ 0) do
    <<padding::size(8), rest::binary>> = data

    if padding == 255 do
      do_calculate_padding_info(rest, current_padding + 254, byte_offset + 1)
    else
      {current_padding + padding, byte_offset + 1}
    end
  end
end
