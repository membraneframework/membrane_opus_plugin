defmodule Membrane.Element.Opus.Encoder do
  @on_load :load_nifs


  def load_nifs do
    :erlang.load_nif('./encoder', 0)
  end


  def world do
    raise "NIF load failed"
  end
end
