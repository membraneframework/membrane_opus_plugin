module Membrane.Opus.Encoder.Native

spec create(input_rate :: int, channels :: int, application :: int) :: state

spec encode_packet(state, payload) :: payload

spec destroy(state) :: :ok
