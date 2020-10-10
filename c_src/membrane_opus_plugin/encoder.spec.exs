module Membrane.Opus.Encoder.Native

spec create(input_rate :: int, channels :: int, application :: int, frame_size :: int) :: state

spec encode_packet(state, payload) ::
       {:ok :: label, payload}
       | {:error :: label, reason :: atom}

spec destroy(state) :: :ok
