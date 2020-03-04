module(Membrane.Element.Opus.Decoder.Native)

spec(
  create(sample_rate :: int, channels :: int) ::
    {:ok :: label, state}
    | {:error :: label, cause :: atom}
)

spec(destroy(state) :: :ok)

spec(get_last_packet_duration(state) :: duration :: int)

spec(
  decode_packet(state, payload, use_fec :: int, duration :: int) ::
    {:ok :: label, payload}
    | {:error :: label, cause :: atom}
)
