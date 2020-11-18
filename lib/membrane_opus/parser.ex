defmodule Membrane.Opus.Parser do
  @moduledoc """
  Parses a raw incoming Opus stream and adds caps information, as well as metadata.

  Adds the following metadata:

  frame_size :: 2.5 | 5 | 10 | 20 | 40 | 60
    Number of milliseconds per frame encoded in this packet.

  frame_lengths :: [non_neg_integer()]
    Ordered list of bytes used to encode each frame in this packet.
    The length of this list is also the number of frames encoded in this packet.
    However, a value of 0 indicates a dropped frame and should be accounted
    for when using this field.
  """

  use Membrane.Filter

  alias Membrane.{Buffer, Opus}

  def_options self_delimit?: [
                spec: boolean(),
                default: false,
                description: """
                If true, will mutate the output to self-delimit the Opus input.

                See https://tools.ietf.org/html/rfc6716#appendix-B for details.
                """
              ]

  def_input_pad :input, demand_unit: :buffers, caps: :any
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
  def handle_process(:input, %Buffer{payload: data}, _ctx, state) do
    with {:ok, {configuration_number, stereo_flag, frame_packing}} <- parse_toc_byte(data),
         {:ok, {_mode, _bandwidth, frame_size}} <- parse_configuration(configuration_number),
         {:ok, channels} <- parse_channels(stereo_flag),
         {:ok, {frame_lengths, header_length}} <- parse_frame_lengths(frame_packing, data),
         {:ok, data} <- self_delimit(data, frame_lengths, header_length, state) do
      caps = %Opus{
        channels: channels,
        self_delimiting?: state.self_delimit?
      }

      buffer = %Buffer{
        payload: data,
        metadata: %{
          frame_lengths: frame_lengths,
          frame_size: frame_size
        }
      }

      {{:ok, caps: {:output, caps}, buffer: {:output, buffer}}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  # handles self-delimiting
  defp self_delimit(data, frame_lengths, header_length, state) when state.self_delimit? do
    <<head::binary-size(header_length), body::binary>> = data

    output =
      [
        head,
        frame_lengths |> List.last() |> encode_frame_length(),
        body
      ]
      |> :binary.list_to_bin()

    {:ok, output}
  end

  defp self_delimit(data, _frame_lengths, _header_length, _state), do: {:ok, data}

  # parses config number, stereo flag, and frame packing strategy from the TOC
  # byte
  defp parse_toc_byte(data) do
    <<configuration_number::size(5), stereo_flag::size(1), frame_packing::size(2), _rest::binary>> =
      data

    {:ok, {configuration_number, stereo_flag, frame_packing}}
  end

  # parses configuration values from TOC configuration number
  defp parse_configuration(configuration_number) do
    case configuration_number do
      0 -> {:ok, {:silk, :narrow, 10}}
      1 -> {:ok, {:silk, :narrow, 20}}
      2 -> {:ok, {:silk, :narrow, 40}}
      3 -> {:ok, {:silk, :narrow, 60}}
      4 -> {:ok, {:silk, :medium, 10}}
      5 -> {:ok, {:silk, :medium, 20}}
      6 -> {:ok, {:silk, :medium, 40}}
      7 -> {:ok, {:silk, :medium, 60}}
      8 -> {:ok, {:silk, :wide, 10}}
      9 -> {:ok, {:silk, :wide, 20}}
      10 -> {:ok, {:silk, :wide, 40}}
      11 -> {:ok, {:silk, :wide, 60}}
      12 -> {:ok, {:hybrid, :super_wide, 10}}
      13 -> {:ok, {:hybrid, :super_wide, 20}}
      14 -> {:ok, {:hybrid, :full, 10}}
      15 -> {:ok, {:hybrid, :full, 20}}
      16 -> {:ok, {:celt, :narrow, 2.5}}
      17 -> {:ok, {:celt, :narrow, 5}}
      18 -> {:ok, {:celt, :narrow, 10}}
      19 -> {:ok, {:celt, :narrow, 20}}
      20 -> {:ok, {:celt, :wide, 2.5}}
      21 -> {:ok, {:celt, :wide, 5}}
      22 -> {:ok, {:celt, :wide, 10}}
      23 -> {:ok, {:celt, :wide, 20}}
      24 -> {:ok, {:celt, :super_wide, 2.5}}
      25 -> {:ok, {:celt, :super_wide, 5}}
      26 -> {:ok, {:celt, :super_wide, 10}}
      27 -> {:ok, {:celt, :super_wide, 20}}
      28 -> {:ok, {:celt, :full, 2.5}}
      29 -> {:ok, {:celt, :full, 5}}
      30 -> {:ok, {:celt, :full, 10}}
      31 -> {:ok, {:celt, :full, 20}}
    end
  end

  # determines number of channels
  defp parse_channels(stereo_flag) when stereo_flag in 0..1, do: {:ok, stereo_flag + 1}

  # returns ordered list of frame lengths
  defp parse_frame_lengths(frame_packing, data) do
    # note, when calculating frame lengths we need to subtract the TOC byte
    case frame_packing do
      # there is one frame in this packet
      0 ->
        {:ok, {[byte_size(data) - 1], 1}}

      # there are two equal-length frames in this packet
      1 ->
        frame_length = div(byte_size(data) - 1, 2)
        {:ok, {[frame_length, frame_length], 1}}

      # there are two non-equal-length frames in this packet
      2 ->
        {first_len, bytes_used} = calculate_frame_length(data, 1)
        {:ok, {[first_len, byte_size(data) - 1 - bytes_used - first_len], 1 + bytes_used}}

      # there are two or more frames of arbitrary size
      3 ->
        {:ok, code_three_lengths(data)}
    end
  end

  # calculates frame lengths for Code 3 packets
  defp code_three_lengths(data) do
    <<_toc::binary-size(1), vbr_flag::size(1), padding_flag::size(1), frame_count::size(6),
      _rest::binary>> = data

    if vbr_flag == 1 do
      code_three_vbr_lengths(data, padding_flag, frame_count)
    else
      code_three_cbr_lengths(data, padding_flag, frame_count)
    end
  end

  defp code_three_vbr_lengths(data, padding_flag, frame_count) do
    {padding_length, padding_encoding_length} = calculate_padding_length(padding_flag, data)
    # 1 for the TOC byte and another for the code 3 frame count byte
    byte_offset = 2 + padding_encoding_length

    # (frame_count - 1) frames have individual frame lengths that we need to
    # calculate, but the last frame's size is implied
    {lengths, byte_offset} =
      0..(frame_count - 2)
      |> Enum.reduce({[], byte_offset}, fn _i, {lengths, byte_offset} ->
        {length, length_encoding_size} = calculate_frame_length(data, byte_offset)
        {[length | lengths], byte_offset + length_encoding_size}
      end)

    last_frame_length = byte_size(data) - byte_offset - Enum.sum(lengths) - padding_length

    frame_lengths =
      [last_frame_length | lengths]
      |> Enum.reverse()

    {frame_lengths, byte_offset}
  end

  defp code_three_cbr_lengths(data, padding_flag, frame_count) do
    {padding_length, padding_encoding_length} = calculate_padding_length(padding_flag, data)
    # 1 for the TOC byte and another for the code 3 frame count byte
    frame_size = div(byte_size(data) - 2 - padding_encoding_length - padding_length, frame_count)

    frame_lengths =
      0..(frame_count - 1)
      |> Enum.map(fn _i -> frame_size end)

    {frame_lengths, 2 + padding_encoding_length}
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
  defp calculate_padding_length(padding_flag, _data) when padding_flag == 0, do: {0, 0}

  defp calculate_padding_length(padding_flag, data) when padding_flag == 1 do
    # TOC byte and code 3 frame count byte
    initial_offset = 2
    {padding_length, offset} = do_calculate_padding_length(data, initial_offset)
    {padding_length, offset - initial_offset}
  end

  defp do_calculate_padding_length(data, byte_offset, current_padding \\ 0) do
    <<_head::binary-size(byte_offset), padding::size(8), _rest::binary>> = data

    if padding == 255 do
      do_calculate_padding_length(data, byte_offset + 1, current_padding + 254)
    else
      {current_padding + padding, byte_offset + 1}
    end
  end
end
