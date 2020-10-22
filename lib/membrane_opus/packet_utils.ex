defmodule Membrane.Opus.PacketUtils do
  @moduledoc false

  def parse_toc(<<config::5, stereo_flag::1, code::2, data::binary>>) do
    {:ok, config, stereo_flag == 1, code, data}
  end

  def parse_toc(_data), do: :end_of_data

  @spec skip_code(code :: integer, data :: binary) ::
          {:cbr | :vbr, frames :: integer, padding :: integer, data :: binary}
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

  def skip_frames(_mode, data, 0) do
    {:ok, data}
  end

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

  def skip_data(size, data) do
    case data do
      <<_to_skip::binary-size(size), data::binary>> -> {:ok, data}
      _data -> :end_of_data
    end
  end

  def encode_frame_size(size) when size in 0..251, do: <<size>>

  def encode_frame_size(size) when size in 252..1275 do
    size = size - 252
    <<252 + rem(size, 4), div(size, 4)>>
  end
end
