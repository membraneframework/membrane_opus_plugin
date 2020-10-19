module Membrane.Opus.Encoder.Native

state_type "State"

spec create(input_rate :: int, channels :: int, application :: int) :: state

spec encode_packet(state, payload, frame_size :: int) ::
       {:ok :: label, payload}
       | {:error :: label, reason :: atom}
