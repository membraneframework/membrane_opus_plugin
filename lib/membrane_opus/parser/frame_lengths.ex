defmodule Membrane.Opus.Parser.FrameLengths do
  @moduledoc false
  # Helper for Membrane.Opus.Parser for determining frame lengths

  # given a frame length, return opus binary encoded length
  @spec encode_frame_length(non_neg_integer) :: binary
  def encode_frame_length(length) do
    if length < 252 do
      <<length::size(8)>>
    else
      <<252 + rem(length - 252, 4)::size(8), div(length - 252, 4)::size(8)>>
    end
  end

  # returns ordered list of frame lengths and header length
  @spec parse_frame_lengths(0..3, binary, boolean) :: {[non_neg_integer], pos_integer}
  def parse_frame_lengths(frame_packing, data_without_toc, self_delimiting?) do
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

  @spec code_zero_lengths(binary, boolean) :: {[non_neg_integer], pos_integer}
  defp code_zero_lengths(data_without_toc, self_delimiting?) do
    if self_delimiting? do
      {length, length_bytes} = calculate_frame_length(data_without_toc, 0)
      {[length], 1 + length_bytes}
    else
      {[byte_size(data_without_toc)], 1}
    end
  end

  @spec code_one_lengths(binary, boolean) :: {[non_neg_integer], pos_integer}
  defp code_one_lengths(data_without_toc, self_delimiting?) do
    if self_delimiting? do
      {length, length_bytes} = calculate_frame_length(data_without_toc, 0)
      {[length, length], 1 + length_bytes}
    else
      length = div(byte_size(data_without_toc), 2)
      {[length, length], 1}
    end
  end

  @spec code_two_lengths(binary, boolean) :: {[non_neg_integer], pos_integer}
  defp code_two_lengths(data_without_toc, self_delimiting?) do
    {first_len, first_bytes_used} = calculate_frame_length(data_without_toc, 0)

    if self_delimiting? do
      {second_len, second_bytes_used} = calculate_frame_length(data_without_toc, first_bytes_used)
      {[first_len, second_len], 1 + first_bytes_used + second_bytes_used}
    else
      second_len = byte_size(data_without_toc) - first_bytes_used - first_len
      {[first_len, second_len], 1 + first_bytes_used}
    end
  end

  @spec code_three_lengths(binary, boolean) :: {[non_neg_integer], pos_integer}
  defp code_three_lengths(data_without_toc, self_delimiting?) do
    <<vbr_flag::size(1), padding_flag::size(1), frame_count::size(6), rest::binary>> =
      data_without_toc

    if vbr_flag == 1 do
      code_three_vbr_lengths(rest, padding_flag, frame_count, self_delimiting?)
    else
      code_three_cbr_lengths(rest, padding_flag, frame_count, self_delimiting?)
    end
  end

  @spec code_three_vbr_lengths(binary, 0..1, non_neg_integer, boolean) ::
          {[non_neg_integer], pos_integer}
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

  @spec code_three_cbr_lengths(binary, 0..1, non_neg_integer, boolean) ::
          {[non_neg_integer], pos_integer}
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
  @spec calculate_frame_length(binary, non_neg_integer) :: {non_neg_integer, 1..2}
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

  # calculates total packet padding length, specifically for code 3 packets,
  # and the number of bytes used to encode the padding length
  @spec calculate_padding_info(0..1, binary) :: {non_neg_integer, non_neg_integer}
  defp calculate_padding_info(padding_flag, data) do
    if padding_flag == 0 do
      {0, 0}
    else
      do_calculate_padding_info(data)
    end
  end

  @spec do_calculate_padding_info(binary, non_neg_integer, non_neg_integer) ::
          {non_neg_integer, non_neg_integer}
  defp do_calculate_padding_info(data, current_padding \\ 0, byte_offset \\ 0) do
    <<padding::size(8), rest::binary>> = data

    if padding == 255 do
      do_calculate_padding_info(rest, current_padding + 254, byte_offset + 1)
    else
      {current_padding + padding, byte_offset + 1}
    end
  end
end
