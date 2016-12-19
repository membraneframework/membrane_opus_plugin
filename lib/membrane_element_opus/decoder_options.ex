defmodule Membrane.Element.Opus.DecoderOptions do
  defstruct \
    sample_rate: 48000, # TODO only 48kHz is supported at the moment
    channels:    2      # TODO only stereo is supported at the moment


  @type t :: %Membrane.Element.Opus.DecoderOptions{
    sample_rate: 48000,
    channels: 2
  }
end
