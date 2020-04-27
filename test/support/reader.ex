defmodule Membrane.Opus.Support.Reader do
  def read_packets(filename) do
    filename
    |> File.read!()
    |> String.split()
    |> Enum.map(fn x ->
      {:ok, y} = Base.decode16(x)
      y
    end)
  end
end
