defmodule Membrane.Opus.Parser.FrameLengths do
  @moduledoc false
  # Helper for Membrane.Opus.Parser for working with frame lengths

  @spec parse(frame_packing :: 0..3, data :: binary, self_delimiting? :: boolean) ::
          {:ok, header_size :: pos_integer, frame_lengths :: [non_neg_integer],
           padding_size :: non_neg_integer}
          | {:error, :cont}
          | :error
  def parse(frame_packing, data, self_delimiting?) do
    case frame_packing do
      # there is one frame in this packet
      0 ->
        code_zero_lengths(data, self_delimiting?)

      # there are two equal-length frames in this packet
      1 ->
        code_one_lengths(data, self_delimiting?)

      # there are two non-equal-length frames in this packet
      2 ->
        code_two_lengths(data, self_delimiting?)

      # there are two or more frames of arbitrary size
      3 ->
        code_three_lengths(data, self_delimiting?)
    end
  end

  @spec code_zero_lengths(data :: binary, self_delimiting? :: boolean) ::
          {:ok, header_size :: pos_integer, frame_lengths :: [non_neg_integer], padding_size :: 0}
          | {:error, :cont}
  defp code_zero_lengths(<<_toc::binary-size(1), rest::binary>>, true) do
    case calculate_frame_length(rest, 0) do
      {length, length_bytes} ->
        {:ok, 1 + length_bytes, [length], 0}

      :error ->
        {:error, :cont}
    end
  end

  defp code_zero_lengths(<<_toc::binary-size(1), rest::binary>>, false) do
    {:ok, 1, [byte_size(rest)], 0}
  end

  @spec code_one_lengths(data :: binary, self_delimiting? :: boolean) ::
          {:ok, header_size :: pos_integer, frame_lengths :: [non_neg_integer], padding_size :: 0}
          | {:error, :cont}
  defp code_one_lengths(<<_toc::binary-size(1), rest::binary>>, true) do
    case calculate_frame_length(rest, 0) do
      {length, length_bytes} ->
        {:ok, 1 + length_bytes, [length, length], 0}

      :error ->
        {:error, :cont}
    end
  end

  defp code_one_lengths(<<_toc::binary-size(1), rest::binary>>, false) do
    length = div(byte_size(rest), 2)
    {:ok, 1, [length, length], 0}
  end

  @spec code_two_lengths(data :: binary, self_delimiting? :: boolean) ::
          {:ok, header_size :: pos_integer, frame_lengths :: [non_neg_integer], padding_size :: 0}
          | {:error, :cont}
  defp code_two_lengths(<<_toc::binary-size(1), rest::binary>>, self_delimiting?) do
    case calculate_frame_length(rest, 0) do
      {first_len, first_bytes_used} ->
        do_code_two_lengths(rest, first_len, first_bytes_used, self_delimiting?)

      :error ->
        {:error, :cont}
    end
  end

  @spec do_code_two_lengths(
          data_without_toc :: binary,
          first_len :: non_neg_integer,
          first_bytes_used :: 1..2,
          self_delimiting? :: boolean
        ) ::
          {:ok, header_size :: pos_integer, frame_lengths :: [non_neg_integer], padding_size :: 0}
          | {:error, :cont}
  defp do_code_two_lengths(data_without_toc, first_len, first_bytes_used, true) do
    case calculate_frame_length(data_without_toc, first_bytes_used) do
      {second_len, second_bytes_used} ->
        {:ok, 1 + first_bytes_used + second_bytes_used, [first_len, second_len], 0}

      :error ->
        {:error, :cont}
    end
  end

  defp do_code_two_lengths(data_without_toc, first_len, first_bytes_used, false) do
    second_len = byte_size(data_without_toc) - first_bytes_used - first_len
    {:ok, 1 + first_bytes_used, [first_len, second_len], 0}
  end

  @spec code_three_lengths(data :: binary, self_delimiting? :: boolean) ::
          {:ok, header_size :: pos_integer, frame_lengths :: [non_neg_integer],
           padding_size :: non_neg_integer}
          | {:error, :cont}
  defp code_three_lengths(data, self_delimiting?) do
    with <<_toc::binary-size(1), vbr_flag::size(1), padding_flag::size(1), frame_count::size(6),
           rest::binary>> <- data,
         {padding_size, padding_encoding_length} <- calculate_padding_info(padding_flag, rest) do
      do_code_three_lengths(
        rest,
        padding_size,
        padding_encoding_length,
        frame_count,
        self_delimiting?,
        vbr_flag == 1
      )
    else
      _ ->
        {:error, :cont}
    end
  end

  @spec do_code_three_lengths(
          data_without_headers :: binary,
          padding_size :: non_neg_integer,
          padding_encoding_length :: non_neg_integer,
          frame_count :: non_neg_integer,
          self_delimiting? :: boolean,
          vbr? :: boolean
        ) ::
          {:ok, header_size :: pos_integer, frame_lengths :: [non_neg_integer],
           padding_size :: non_neg_integer}
          | {:error, :cont}
          | :error
  # VBR regardless of delimiting
  defp do_code_three_lengths(
         data_without_headers,
         padding_size,
         padding_encoding_length,
         frame_count,
         self_delimiting?,
         true
       ) do
    byte_offset = padding_encoding_length

    frames_with_lengths =
      if self_delimiting? do
        frame_count
      else
        # (frame_count - 1) frames have individual frame lengths that we need to
        # calculate, but the last frame's size is implied
        frame_count - 1
      end

    reduction =
      0..(frames_with_lengths - 1)
      |> Bunch.Enum.try_map_reduce(byte_offset, fn _i, byte_offset ->
        case calculate_frame_length(data_without_headers, byte_offset) do
          {length, length_encoding_size} ->
            {{:ok, length}, byte_offset + length_encoding_size}

          :error ->
            {{:error, "Bad frame length"}, byte_offset}
        end
      end)

    case reduction do
      {{:ok, lengths}, byte_offset} ->
        if self_delimiting? do
          # adding 2 for TOC and code three header
          {:ok, 2 + byte_offset, lengths, padding_size}
        else
          last_frame_length =
            byte_size(data_without_headers) - byte_offset - Enum.sum(lengths) - padding_size

          # adding 2 for TOC and code three header
          {:ok, 2 + byte_offset, lengths ++ [last_frame_length], padding_size}
        end

      {{:error, _reason}, _offset} ->
        if self_delimiting? do
          {:error, :cont}
        else
          :error
        end
    end
  end

  # CBR self-delimiting
  defp do_code_three_lengths(
         data_without_headers,
         padding_size,
         padding_encoding_length,
         frame_count,
         true,
         false
       ) do
    case calculate_frame_length(data_without_headers, padding_encoding_length) do
      {frame_duration, bytes_used} ->
        # adding 2 for TOC and code three header
        header_size = 2 + padding_encoding_length + bytes_used
        frame_lengths = 0..(frame_count - 1) |> Enum.map(fn _i -> frame_duration end)
        {:ok, header_size, frame_lengths, padding_size}

      :error ->
        {:error, :cont}
    end
  end

  # CBR not self-delimiting
  defp do_code_three_lengths(
         data_without_headers,
         padding_size,
         padding_encoding_length,
         frame_count,
         false,
         false
       ) do
    frame_duration =
      div(
        byte_size(data_without_headers) - padding_encoding_length - padding_size,
        frame_count
      )

    # adding 2 for TOC and code three header
    header_size = 2 + padding_encoding_length
    frame_lengths = 0..(frame_count - 1) |> Enum.map(fn _i -> frame_duration end)
    {:ok, header_size, frame_lengths, padding_size}
  end

  @spec calculate_frame_length(data :: binary, byte_offset :: non_neg_integer) ::
          {frame_length :: non_neg_integer, frame_length_encoding_size :: 1..2} | :error
  defp calculate_frame_length(data, byte_offset) when byte_size(data) < byte_offset + 1,
    do: :error

  defp calculate_frame_length(data, byte_offset) do
    <<_head::binary-size(byte_offset), length, rest::binary>> = data

    cond do
      length < 252 ->
        {length, 1}

      byte_size(rest) >= 1 ->
        <<overflow_length, _rest::binary>> = rest

        # https://tools.ietf.org/html/rfc6716#section-3.1
        {overflow_length * 4 + length, 2}

      true ->
        :error
    end
  end

  @spec calculate_padding_info(
          padding_flag :: 0..1,
          data :: binary,
          current_padding :: non_neg_integer,
          byte_offset :: non_neg_integer
        ) ::
          {padding_size :: non_neg_integer, padding_encoding_size :: non_neg_integer} | :error
  defp calculate_padding_info(padding_flag, data, current_padding \\ 0, byte_offset \\ 0)

  defp calculate_padding_info(0, _data, _current_padding, _byte_offset) do
    {0, 0}
  end

  defp calculate_padding_info(1, <<padding::size(8), rest::binary>>, current_padding, byte_offset)
       when padding == 255 do
    calculate_padding_info(1, rest, current_padding + 254, byte_offset + 1)
  end

  defp calculate_padding_info(
         1,
         <<padding::size(8), _rest::binary>>,
         current_padding,
         byte_offset
       ) do
    {current_padding + padding, byte_offset + 1}
  end

  defp calculate_padding_info(1, _data, _current_padding, _byte_offset) do
    :error
  end
end
