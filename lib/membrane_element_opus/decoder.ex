defmodule Membrane.Element.Opus.DecoderOptions do
  defstruct \
    sample_rate: 48000, # TODO only 48kHz is supported at the moment
    channels:    2,     # TODO only stereo is supported at the moment
    frame_size:  10,    # one of 2.5, 5, 10, 20, 40, 60
    fec:         false
end


defmodule Membrane.Element.Opus.Decoder do
  @moduledoc """
  This element performs decoding of Opus audio.
  """

  use Membrane.Element.Base.Filter
  alias Membrane.Element.Opus.DecoderNative
  alias Membrane.Element.Opus.DecoderOptions


  def handle_prepare(%DecoderOptions{frame_size: frame_size, sample_rate: sample_rate, channels: channels}) do
    case DecoderNative.create(sample_rate, channels, application) do
      {:ok, native} ->
        {:ok, %{
          native: native,
          queue: << >>
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end


  def handle_buffer(%Membrane.Caps{content: "audio/x-opus"}, data, %{native: native, fec: fec, queue: queue} = state) do
    # {:ok, {decoded_data, decoded_channels}} = DecoderNative.decoder_int(native, data, fec)

    # {:send_buffer, {%Membrane.Caps{content: "audio/x-raw", channels: decoded_channels}, decoded_data}

    {:ok, state} # TODO
  end
end
