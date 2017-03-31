defmodule Membrane.Element.Opus.EncoderOptions do
  @moduledoc """
  This module defines a struct that represents options passed while initializing
  a `Membrane.Element.Opus.Encoder`.

  The default values of particular fields are:

  * bitrate: `98304` (96 kbit/s),
  * sample_rate: `48000` (48 kHz),
  * channels: `2` (stereo),
  * application: `:audio` (generic audio stream),
  * frame_duration: `10` (10 ms),
  * packet_loss: `0` (no overhead for packet reconstruction).

  Bitrate has to be in range <6144, 522240> (according to the libopus
  documentation, supported bitrates are from 6 to 510 kbit/s).

  Sample rate has to be one of 8000, 12000, 16000, 24000, or 48000.

  Channels at the moment has to be equal to 2. (TODO)

  Application has to be one of `:audio`, `:voip` and `:restricted_lowdelay`.
  See Opus documentation for detailed explanation of these modes.

  Frame duration has to be one of `2`, `5`, `10`, `20`, `40`, `60`. If it is
  set to `2` it means that frame will have 2.5 ms, otherwise it will just
  represent frame duration in milliseconds.
  """

  defstruct \
    bitrate:        98304,
    sample_rate:    48000,
    channels:       2,
    application:    :audio,
    frame_duration: 10,
    packet_loss:    0,
    enable_fec:     true


  @type bitrate_t        :: Membrane.Caps.Audio.Opus.bitrate_t
  @type sample_rate_t    :: Membrane.Caps.Audio.Opus.sample_rate_t
  @type channels_t       :: 2 # TODO
  @type application_t    :: Membrane.Caps.Audio.Opus.application_t
  @type frame_duration_t :: Membrane.Caps.Audio.Opus.frame_duration_t
  @type packet_loss_t    :: Membrane.Caps.Audio.Opus.packet_loss_t
  @type enable_fec_t       :: boolean

  @type t :: %Membrane.Element.Opus.EncoderOptions{
    bitrate: bitrate_t,
    sample_rate: sample_rate_t,
    channels: channels_t,
    application: application_t,
    frame_duration: frame_duration_t,
    packet_loss: packet_loss_t,
    enable_fec: enable_fec_t,
  }
end
