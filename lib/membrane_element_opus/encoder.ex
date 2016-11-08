defmodule Membrane.Element.Opus.EncoderOptions do
  defstruct \
    bitrate:     96 * 1024,
    sample_rate: 48000, # FIXME only 48kHz is supported at the moment
    channels:    2,     # FIXME only stereo is supported at the moment
    application: :audio,
    frame_size:  10
end


defmodule Membrane.Element.Opus.Encoder do
  use Membrane.Element.Base.Filter


  def handle_prepare(%Membrane.Element.Opus.EncoderOptions{frame_size: frame_size, bitrate: bitrate, sample_rate: sample_rate, channels: channels, application: application}) do
    case Membrane.Element.Opus.EncoderNative.create(sample_rate, channels, application) do
      {:ok, native} ->
        case Membrane.Element.Opus.EncoderNative.set_bitrate(native, bitrate) do
          :ok ->
            # Cache size in samples and bytes of one packet for given Opus
            # frame size.
            #
            # Byte size is equal to amount of samples for duration specified by
            # frame size for given sample rate multiplied by amount of channels
            # multiplied by 2 (Opus always # uses 16-bit frames).
            # FIXME Hardcoded 2 channels, 48 kHz
            packet_size_in_samples = compute_samples_for_frame_size(sample_rate, frame_size);
            packet_size_in_bytes = packet_size_in_samples * 2 * 2;

            {:ok, %{
              native: native,
              bitrate: bitrate,
              packet_size_in_samples: packet_size_in_samples,
              packet_size_in_bytes: packet_size_in_bytes,
              queue: << >>
            }}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end


  def handle_buffer(%Membrane.Caps{content: "audio/x-raw", sample_rate: 48000, channels: 2, endianness: :le, frame_size: 2}, data, %{packet_size_in_samples: packet_size_in_samples, packet_size_in_bytes: packet_size_in_bytes, native: native, queue: queue} = state) do
    # If we have more data in the buffer than required, split them as packets
    # of required size recursively. Keep the remaining buffer for future calls.
    {encoded_buffers, new_queue} = prepare_encoded_buffers(queue <> data, packet_size_in_bytes, packet_size_in_samples, native, []);

    {:send_buffer, encoded_buffers, %{state | queue: new_queue}}
  end


  # For 48kHz
  defp compute_samples_for_frame_size(48000, 60), do: 2880
  defp compute_samples_for_frame_size(48000, 40), do: 1820
  defp compute_samples_for_frame_size(48000, 20), do: 960
  defp compute_samples_for_frame_size(48000, 10), do: 480
  defp compute_samples_for_frame_size(48000, 5), do: 240
  defp compute_samples_for_frame_size(48000, 2.5), do: 120


  defp prepare_encoded_buffers(data, packet_size_in_bytes, packet_size_in_samples, native, acc) do
    cond do
      byte_size(data) > packet_size_in_bytes ->
        << packet_data :: binary-size(packet_size_in_bytes), rest :: binary >> = data
        prepare_encoded_buffers(rest, packet_size_in_bytes, packet_size_in_samples, native, [encode(packet_data, native, packet_size_in_samples)|acc])

      byte_size(data) == packet_size_in_bytes ->
        {[encode(data, native, packet_size_in_samples)|acc], << >>}

      byte_size(data) < packet_size_in_bytes ->
        {acc, data}
    end
  end


  defp encode(packet_data, native, packet_size_in_samples) do
    {:ok, encoded_data} = Membrane.Element.Opus.EncoderNative.encode_int(native, packet_data, packet_size_in_samples)

    {%Membrane.Caps{content: "audio/x-opus"}, encoded_data}
  end
end
