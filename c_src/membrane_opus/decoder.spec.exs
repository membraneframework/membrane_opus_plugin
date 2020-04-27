module Membrane.Opus.Decoder.Native

spec create(sample_rate :: int, channels :: int) ::
       {:ok :: label, state}
       | {:error :: label, cause :: atom}

spec decode_packet(state, payload) ::
       {:ok :: label, payload}
       | {:error :: label, cause :: atom}

spec destroy(state) :: :ok
