defmodule Membrane.Element.Opus.Decoder do
  use Membrane.Element.Base.Filter


  def handle_buffer(%Membrane.Caps{content: "audio/x-opus"}, data, state) do
    {:ok, state} # TODO
  end
end
