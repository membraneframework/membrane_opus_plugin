defmodule Membrane.Element.Opus.Encoder do
  @moduledoc """
  This element performs encoding of raw audio using Opus codec.

  At the moment it accepts only 48000 kHz, stereo, 16-bit, little-endian audio.
  """

  use Membrane.Element.Base.Filter
  alias Membrane.Element.Opus.EncoderNative
  alias Membrane.Element.Opus.EncoderOptions
  alias Membrane.Helper.Bitstring


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
  def handle_prepare(%{frame_duration: frame_duration, bitrate: bitrate, sample_rate: sample_rate, channels: channels, application: application} = state) do
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
            frame_size_in_samples = frame_samples_count(sample_rate, frame_duration);
            frame_size_in_bytes = frame_size_in_samples * @channels * @sample_size_in_bytes;

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


  @doc false
  def handle_buffer(%Membrane.Buffer{caps: %Membrane.Caps.Audio.Raw{sample_rate: 48000, format: :s16le}, payload: payload}, %{frame_size_in_bytes: frame_size_in_bytes, queue: queue} = state) do
    {:ok, encoded_buffers, new_queue} = queue <> payload
      |> Bitstring.split_map(frame_size_in_bytes, &encode/2, [state])

    {:send, encoded_buffers, %{state | queue: new_queue}}
  end


  defp frame_samples_count(48000, 60), do: 2880
  defp frame_samples_count(48000, 40), do: 1820
  defp frame_samples_count(48000, 20), do: 960
  defp frame_samples_count(48000, 10), do: 480
  defp frame_samples_count(48000, 5), do: 240
  defp frame_samples_count(48000, 2), do: 120


  # Does the actual encoding of frame payload that already is split to parts
  # of the desired size.
  defp encode(frame_payload, %{frame_size_in_samples: frame_size_in_samples, frame_duration: frame_duration, native: native}) do
    {:ok, encoded_payload} = native
      |> EncoderNative.encode_int(frame_payload, frame_size_in_samples)

    %Membrane.Buffer{
      caps: %Membrane.Caps.Audio.Opus{
        channels: @channels,
        frame_duration: frame_duration
      },
      payload: encoded_payload
    }
  end
end
