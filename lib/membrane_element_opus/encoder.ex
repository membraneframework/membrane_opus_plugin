defmodule Membrane.Element.Opus.Encoder do
  @moduledoc """
  This element performs encoding of raw audio using Opus codec.

  At the moment it accepts only 48000 kHz, stereo, 16-bit, little-endian audio.
  """

  use Membrane.Element.Base.Filter
  alias Membrane.Element.Opus.EncoderNative
  alias Membrane.Element.Opus.EncoderOptions
  alias Membrane.Helper.Bitstring


  def_known_source_pads %{
    :source => {:always, [
      %Membrane.Caps.Audio.Opus{},
    ]}
  }

  # TODO support float samples
  def_known_sink_pads %{
    :sink => {:always, [
      %Membrane.Caps.Audio.Raw{sample_rate: 48000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 24000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 16000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 12000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 8000,  format: :s16le},
    ]}
  }

  @channels 2
  @sample_size_in_bytes 2


  # Private API

  @doc false
  def handle_init(%EncoderOptions{frame_duration: frame_duration, bitrate: bitrate, sample_rate: sample_rate, channels: channels, application: application}) do
    {:ok, %{
      frame_duration: frame_duration,
      bitrate: bitrate,
      sample_rate: sample_rate,
      channels: channels,
      application: application,
      frame_size_in_samples: nil,
      frame_size_in_bytes: nil,
    }}
  end


  @doc false
  # FIXME move sample_rate/channels setup to new handle_caps
  def handle_prepare(_prev_state, %{frame_duration: frame_duration, bitrate: bitrate, sample_rate: sample_rate, channels: channels, application: application} = state) do
    case EncoderNative.create(sample_rate, channels, application) do
      {:ok, native} ->
        case EncoderNative.set_bitrate(native, bitrate) do
          :ok ->
            # Store size in samples and bytes of one frame for given Opus
            # frame size. This is later required both by encoder (it expects
            # samples' count to each encode call) and by algorithm chopping
            # incoming buffers into frames of size expected by the encoder.
            #
            # frame size in bytes is equal to amount of samples for duration
            # specified by frame size for given sample rate multiplied by amount
            # of channels multiplied by 2 (Opus always uses 16-bit frames).
            frame_size_in_samples = frame_samples_count(sample_rate, frame_duration)
            frame_size_in_bytes = frame_size_in_samples * @channels * @sample_size_in_bytes

            {:ok, %{state |
              native: native,
              frame_size_in_samples: frame_size_in_samples,
              frame_size_in_bytes: frame_size_in_bytes,
              queue: << >>
            }}

          {:error, reason} ->
            {:error, reason, %{state |
              native: nil,
              frame_size_in_samples: nil,
              frame_size_in_bytes: nil,
              queue: << >>
            }}
        end

      {:error, reason} ->
        {:error, reason, %{state |
          native: nil,
          frame_size_in_samples: nil,
          frame_size_in_bytes: nil,
          queue: << >>
        }}
    end
  end


  # FIXME do not hardcode sample rate
  @doc false
  def handle_buffer(:sink, %Membrane.Caps.Audio.Raw{sample_rate: 48000, format: :s16le}, %Membrane.Buffer{payload: payload}, %{frame_size_in_bytes: frame_size_in_bytes, queue: queue} = state) do
    {:ok, encoded_buffers, new_queue} = queue <> payload
      |> Bitstring.split_map(frame_size_in_bytes, &encode/2, [state])

    {:ok, [{:send, {:source, %Membrane.Buffer{payload: encoded_buffers}}}], %{state | queue: new_queue}}
  end


  # Frame duration in samples for 48 kHz
  defp frame_samples_count(48000, 60), do: 2880
  defp frame_samples_count(48000, 40), do: 1920
  defp frame_samples_count(48000, 20), do: 960
  defp frame_samples_count(48000, 10), do: 480
  defp frame_samples_count(48000, 5),  do: 240
  defp frame_samples_count(48000, 2),  do: 120


  # Frame duration in samples for 24 kHz
  defp frame_samples_count(24000, 60), do: 1440
  defp frame_samples_count(24000, 40), do: 960
  defp frame_samples_count(24000, 20), do: 480
  defp frame_samples_count(24000, 10), do: 240
  defp frame_samples_count(24000, 5),  do: 120
  defp frame_samples_count(24000, 2),  do: 60


  # Frame duration in samples for 16 kHz
  defp frame_samples_count(16000, 60), do: 960
  defp frame_samples_count(16000, 40), do: 640
  defp frame_samples_count(16000, 20), do: 320
  defp frame_samples_count(16000, 10), do: 160
  defp frame_samples_count(16000, 5),  do: 80
  defp frame_samples_count(16000, 2),  do: 40


  # Frame duration in samples for 12 kHz
  defp frame_samples_count(12000, 60), do: 720
  defp frame_samples_count(12000, 40), do: 480
  defp frame_samples_count(12000, 20), do: 240
  defp frame_samples_count(12000, 10), do: 120
  defp frame_samples_count(12000, 5),  do: 60
  defp frame_samples_count(12000, 2),  do: 30


  # Frame duration in samples for 8 kHz
  defp frame_samples_count(8000, 60),  do: 480
  defp frame_samples_count(8000, 40),  do: 320
  defp frame_samples_count(8000, 20),  do: 160
  defp frame_samples_count(8000, 10),  do: 80
  defp frame_samples_count(8000, 5),   do: 40
  defp frame_samples_count(8000, 2),   do: 20


  # Does the actual encoding of frame payload that already is split to parts
  # of the desired size.
  defp encode(frame_payload, %{frame_size_in_samples: frame_size_in_samples, native: native}) do
    {:ok, encoded_payload} = native
      |> EncoderNative.encode_int(frame_payload, frame_size_in_samples)

    %Membrane.Buffer{payload: encoded_payload}
  end
end
