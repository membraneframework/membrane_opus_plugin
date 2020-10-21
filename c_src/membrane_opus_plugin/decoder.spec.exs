module Membrane.Opus.Decoder.Native

spec create(sample_rate :: int, channels :: int) :: state

spec decode_packet(state, payload) :: payload
