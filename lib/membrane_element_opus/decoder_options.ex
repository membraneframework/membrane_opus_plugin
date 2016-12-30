defmodule Membrane.Element.Opus.DecoderOptions do
  @moduledoc """
  This module defines a struct that represents options passed while initializing
  a `Membrane.Element.Opus.Decoder`.

  The default values of particular fields are:

  * sample_rate: `48000` (48 kHz),
  * channels: `2` (stereo),
  * fec: `false` (disabled).

  Sample rate has to be one of 8000, 12000, 16000, 24000, or 48000.

  Channels at the moment has to be equal to 2. (TODO)

  FEC (Forward Error Correction) has to be either `true` or `false`. Please
  note that for make FEC working you should set non-zero packet loss perctage
  in the encoder.
  """

  defstruct \
    sample_rate: 48000,
    channels:    2,
    fec:         false


  @type sample_rate_t :: Membrane.Caps.Audio.Opus.sample_rate_t

  @type t :: %Membrane.Element.Opus.DecoderOptions{
    sample_rate: sample_rate_t,
    channels: 2,
    fec: boolean
  }
end
