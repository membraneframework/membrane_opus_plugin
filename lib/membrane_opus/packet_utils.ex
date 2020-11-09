defmodule Membrane.Opus.PacketUtils do
  @moduledoc false

  alias Membrane.Opus

  # Refer to https://tools.ietf.org/html/rfc6716#section-3.1
  @toc_config_map %{
    0 => {:silk, :narrow, 10_000},
    1 => {:silk, :narrow, 20_000},
    2 => {:silk, :narrow, 40_000},
    3 => {:silk, :narrow, 60_000},
    4 => {:silk, :medium, 10_000},
    5 => {:silk, :medium, 20_000},
    6 => {:silk, :medium, 40_000},
    7 => {:silk, :medium, 60_000},
    8 => {:silk, :wide, 10_000},
    9 => {:silk, :wide, 20_000},
    10 => {:silk, :wide, 40_000},
    11 => {:silk, :wide, 60_000},
    12 => {:hybrid, :super_wide, 10_000},
    13 => {:hybrid, :super_wide, 20_000},
    14 => {:hybrid, :full, 10_000},
    15 => {:hybrid, :full, 20_000},
    16 => {:celt, :narrow, 2_500},
    17 => {:celt, :narrow, 5_000},
    18 => {:celt, :narrow, 10_000},
    19 => {:celt, :narrow, 20_000},
    20 => {:celt, :wide, 2_500},
    21 => {:celt, :wide, 5_000},
    22 => {:celt, :wide, 10_000},
    23 => {:celt, :wide, 20_000},
    24 => {:celt, :super_wide, 2_500},
    25 => {:celt, :super_wide, 5_000},
    26 => {:celt, :super_wide, 10_000},
    27 => {:celt, :super_wide, 20_000},
    28 => {:celt, :full, 2_500},
    29 => {:celt, :full, 5_000},
    30 => {:celt, :full, 10_000},
    31 => {:celt, :full, 20_000}
  }

  @spec skip_toc(data :: binary) ::
          {:ok,
           %{
             mode: :silk | :hybrid | :celt,
             bandwidth: :narrow | :medium | :wide | :super_wide | :full,
             frame_duration: Membrane.Time.non_neg_t(),
             channels: Opus.channels_t(),
             code: 0..3
           }, data :: binary}
          | :end_of_data
  def skip_toc(<<config::5, stereo_flag::1, code::2, data::binary>>) do
    {mode, bandwidth, frame_duration} = Map.fetch!(@toc_config_map, config)

    {:ok,
     %{
       mode: mode,
       bandwidth: bandwidth,
       frame_duration: Membrane.Time.microseconds(frame_duration),
       channels: stereo_flag + 1,
       code: code
     }, data}
  end

  def skip_toc(_data), do: :end_of_data

  @spec skip_code(code :: integer, data :: binary) ::
          {:ok, :cbr | :vbr, frames_count :: integer, padding_len :: integer, data :: binary}
          | :end_of_data
  def skip_code(0, data), do: {:ok, :cbr, 1, 0, data}
  def skip_code(1, data), do: {:ok, :cbr, 2, 0, data}
  def skip_code(2, data), do: {:ok, :vbr, 2, 0, data}

  def skip_code(3, <<mode::1, 1::1, frames::6, pad_len::8, data::binary>>) do
    mode = if mode == 0, do: :cbr, else: :vbr
    {:ok, mode, frames, pad_len, data}
  end

  def skip_code(3, <<mode::1, 0::1, frames::6, data::binary>>) do
    mode = if mode == 0, do: :cbr, else: :vbr
    {:ok, mode, frames, 0, data}
  end

  def skip_code(_code, _data), do: :end_of_data

  @spec skip_frame_sizes(mode :: :cbr | :vbr, data :: binary, frames_count :: integer) ::
          {:ok, frames_size :: integer, data :: binary} | :end_of_data
  def skip_frame_sizes(:cbr, data, frames) do
    with {:ok, size, data} <- do_skip_frame_sizes(data, min(frames, 1), 0) do
      {:ok, frames * size, data}
    end
  end

  def skip_frame_sizes(:vbr, data, frames), do: do_skip_frame_sizes(data, frames, 0)

  defp do_skip_frame_sizes(data, 0, acc), do: {:ok, acc, data}

  defp do_skip_frame_sizes(<<size, data::binary>>, frames, acc) when size <= 251,
    do: do_skip_frame_sizes(data, frames - 1, acc + size)

  defp do_skip_frame_sizes(<<size1, size2, data::binary>>, frames, acc) when size1 >= 252,
    do: do_skip_frame_sizes(data, frames - 1, acc + size1 + size2 * 4)

  defp do_skip_frame_sizes(_data, _frames, _total), do: :end_of_data

  @spec skip_data(size :: non_neg_integer(), data :: binary) ::
          {:ok, data :: binary()} | :end_of_data
  def skip_data(size, data) do
    case data do
      <<_to_skip::binary-size(size), data::binary>> -> {:ok, data}
      _data -> :end_of_data
    end
  end

  @spec encode_frame_size(pos_integer) :: binary
  def encode_frame_size(size) when size in 0..251, do: <<size>>

  def encode_frame_size(size) when size in 252..1275 do
    size = size - 252
    <<252 + rem(size, 4), div(size, 4)>>
  end
end
