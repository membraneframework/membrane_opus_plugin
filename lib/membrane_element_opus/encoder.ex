defmodule Membrane.Element.Opus.Encoder do
  @moduledoc """
  This element performs encoding of raw audio using Opus codec.
  """

  use Membrane.Filter

  def_input_pad :input,
    caps: :any,
    demand_unit: :buffers

  def_output_pad :output,
    caps: :any

  @impl true
  def handle_init(_opts) do
    {:ok, nil}
  end

  @impl true
  def handle_process(:input, buffer, _context, state) do
    {{:ok, buffer: buffer}, state}
  end
end
