defmodule Membrane.Element.Opus.Event.Bitrate do
  @moduledoc """
  Structure representing payload of the event with type :set_bitrate.

  Contains request of changing encoder's bitrate to specified value, during
  the runtime.
  """

  defstruct new_bitrate: 0

  @type t :: %Membrane.Element.Opus.Event.Bitrate{
          new_bitrate: float
        }
end
