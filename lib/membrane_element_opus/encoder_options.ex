defmodule Membrane.Element.Opus.EncoderOptions do
  defstruct \
    bitrate:        96 * 1024,
    sample_rate:    48000, # TODO only 48kHz is supported at the moment
    channels:       2,     # TODO only stereo is supported at the moment
    application:    :audio,
    frame_duration: 10


  @type t :: %Membrane.Element.Opus.EncoderOptions{
    bitrate: non_neg_integer,
    sample_rate: 48000,
    channels: 2,
    application: :audio | :voip | :restricted_lowdelay,
    frame_duration: Membrane.Caps.Audio.Opus.frame_duration_t
  }
end
