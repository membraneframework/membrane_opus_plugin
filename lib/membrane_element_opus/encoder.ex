defmodule Membrane.Element.Opus.EncoderOptions do
  defstruct \
    bitrate:     96 * 1024,
    sample_rate: 48000, # TODO only 48kHz is supported at the moment
    channels:    2,     # TODO only stereo is supported at the moment
    application: :audio,
    frame_size:  10     # one of 2.5, 5, 10, 20, 40, 60
end


defmodule Membrane.Element.Opus.Encoder do
  @moduledoc """
  This element performs encoding of raw audio using Opus codec.

  At the moment it accepts only 48000 kHz, stereo, 16-bit, little-endian audio.
  """

  use Membrane.Element.Base.Filter


  def handle_prepare(%Membrane.Element.Opus.EncoderOptions{frame_size: frame_size, bitrate: bitrate, sample_rate: sample_rate, channels: channels, application: application}) do
    case Membrane.Element.Opus.EncoderNative.create(sample_rate, channels, application) do
      {:ok, native} ->
        case Membrane.Element.Opus.EncoderNative.set_bitrate(native, bitrate) do
          :ok ->
            # Store size in samples and bytes of one packet for given Opus
            # frame size. This is later required both by encoder (it expects
            # samples' count to each encode call) and by algorithm chopping
            # incoming buffers into packets of size expected by the encoder.
            #
            # Packet size in bytes is equal to amount of samples for duration
            # specified by frame size for given sample rate multiplied by amount
            # of channels multiplied by 2 (Opus always uses 16-bit frames).
            #
            # TODO Hardcoded 2 channels, 48 kHz
            packet_size_in_samples = packet_samples_count(sample_rate, frame_size);
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


  # TODO support other sample rates and channels
  def handle_buffer(%Membrane.Caps{content: "audio/x-raw", sample_rate: 48000, channels: 2, endianness: :le, frame_size: 2}, data, %{packet_size_in_samples: packet_size_in_samples, packet_size_in_bytes: packet_size_in_bytes, native: native, queue: queue} = state) do
    # If we have more data in the buffer than required, split them as packets
    # of required size recursively. Keep the remaining buffer for future calls.
    {encoded_buffers, new_queue} = prepare_encoded_buffers(queue <> data, packet_size_in_bytes, packet_size_in_samples, native, []);

    {:send_buffer, encoded_buffers, %{state | queue: new_queue}}
  end


  # TODO only For 48kHz
  defp packet_samples_count(48000, 60), do: 2880
  defp packet_samples_count(48000, 40), do: 1820
  defp packet_samples_count(48000, 20), do: 960
  defp packet_samples_count(48000, 10), do: 480
  defp packet_samples_count(48000, 5), do: 240
  defp packet_samples_count(48000, 2.5), do: 120


  # Chops queue with data into packets of size expected by the Opus encoder.
  # It encodes each packet and creates new buffer to be sent to linked elements.
  # At the end of recursion it returns `{list_of_encoded_buffers, remaining_queue}`.
  defp prepare_encoded_buffers(queue, packet_size_in_bytes, packet_size_in_samples, native, acc) do
    cond do
      # We have more queue in the queue than we need for single packet.
      # Encode one packet and recurse.
      byte_size(queue) > packet_size_in_bytes ->
        << packet_data :: binary-size(packet_size_in_bytes), rest :: binary >> = queue
        prepare_encoded_buffers(rest, packet_size_in_bytes, packet_size_in_samples, native, [encode(native, packet_data, packet_size_in_samples)|acc])

      # We have exact amount of queue in the queue for a single packet.
      # Encode it and return with empty queue.
      byte_size(queue) == packet_size_in_bytes ->
        {[encode(native, queue, packet_size_in_samples)|acc], << >>}

      # We have less queue in the queue than we need for a single packet.
      # Do nothing and return with unmodified queue.
      byte_size(queue) < packet_size_in_bytes ->
        {acc, queue}
    end
  end


  # Does the actual encoding of packet data that already has desired size.
  defp encode(native, packet_data, packet_size_in_samples) do
    {:ok, encoded_data} = Membrane.Element.Opus.EncoderNative.encode_int(native, packet_data, packet_size_in_samples)

    {%Membrane.Caps{content: "audio/x-opus"}, encoded_data}
  end
end
