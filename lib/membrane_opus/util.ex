defmodule Membrane.Opus.Util do
  @moduledoc false
  # Miscellaneous utility functions

  import Membrane.Time

  @spec parse_toc_byte(data :: binary) ::
          {config_number :: 0..31, stereo_flag :: 0..1, frame_packing :: 0..3} | :error
  def parse_toc_byte(
        <<config_number::size(5), stereo_flag::size(1), frame_packing::size(2), _rest::binary>>
      ) do
    {config_number, stereo_flag, frame_packing}
  end

  def parse_toc_byte(_data) do
    :error
  end

  @spec parse_channels(stereo_flag :: 0..1) :: channels :: 1..2
  def parse_channels(stereo_flag) when stereo_flag in 0..1 do
    stereo_flag + 1
  end

  @spec parse_configuration(config_number :: 0..31) ::
          {mode :: :silk | :hybrid | :celt,
           bandwidth :: :narrow | :medium | :wide | :super_wide | :full,
           frame_duration :: Membrane.Time.non_neg_t()}
  def parse_configuration(configuration_number) do
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
end
