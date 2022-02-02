defmodule Membrane.Opus.Support.Reader do
  @moduledoc false
  @spec read_packets(Path.t()) :: [binary()]
  def read_packets(filename) do
    filename
    |> File.read!()
    |> String.split()
    |> Enum.map(&Base.decode16!/1)
  end
end
