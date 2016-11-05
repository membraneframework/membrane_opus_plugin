defmodule Membrane.Element.Opus.Encoder do
  use Membrane.Element.Base.Filter


  def handle_buffer(%Membrane.Caps{content: "audio/x-raw"}, data, state) do
    {:ok, state} # TODO
  end
end
