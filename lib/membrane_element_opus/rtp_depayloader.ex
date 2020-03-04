defmodule Membrane.Element.Opus.RTPDepayloader do
  @moduledoc """
  This element performs decoding of Opus audio.
  """

  use Membrane.Filter

  alias Membrane.Buffer
  alias Membrane.Caps.{RTP, Audio.Opus}

  def_input_pad :input,
    caps: {RTP, payload_type: :dynamic},
    demand_unit: :buffers

  def_output_pad :output,
    caps: {Opus, []}

  @impl true
  def handle_init(_options) do
    {:ok, nil}
  end

  @impl true
  def handle_process(:input, buffer, _context, state) do
    {{:ok, buffer: {:output, buffer}}, state}
  end

  @impl true
  def handle_demand(_pad, size, unit, _context, state) do
    {{:ok, demand: {:input, size}}, state}
  end
end
