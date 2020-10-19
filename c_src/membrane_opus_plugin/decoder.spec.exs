module Membrane.Opus.Decoder.Native

state_type "State"

spec create(sample_rate :: int, channels :: int) :: state

spec decode_packet(state, payload) :: payload
