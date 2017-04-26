defmodule Membrane.Element.Opus.Event.PacketLoss do
  @moduledoc """
  Structure representing payload of the event with type :packet_loss.

  Contains information about percentage number of packet that have been dropped
  on the way to the decoder.
  """

  defstruct \
    percentage: 0

  @type t :: %Membrane.Element.Opus.Event.PacketLoss{
    percentage: float
  }
end
