defmodule Membrane.Element.Opus.Decoder do
  @moduledoc """
  This element performs decoding of Opus audio.
  """

  use Membrane.Element.Base.Filter
  alias Membrane.Element.Opus.DecoderNative
  alias Membrane.Element.Opus.DecoderOptions


  # TODO support float samples
  def_known_source_pads %{
    :sink => {:always, [
      %Membrane.Caps.Audio.Raw{sample_rate: 48000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 24000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 16000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 12000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 8000,  format: :s16le},
    ]}
  }

  def_known_sink_pads %{
    :source => {:always, [
      %Membrane.Caps.Audio.Opus{},
    ]}
  }


  # Private API

  @doc false
  def handle_init(%DecoderOptions{sample_rate: sample_rate, channels: channels}) do
    {:ok, %{
      sample_rate: sample_rate,
      channels: channels,
      native: nil,
      queue: << >>
    }}
  end


  @doc false
  def handle_prepare(_prev_state, %{sample_rate: sample_rate, channels: channels} = state) do
    case DecoderNative.create(sample_rate, channels) do
      {:ok, native} ->
        {:ok, %{state | native: native}}

      {:error, reason} ->
        {:error, reason, %{state | native: nil}}
    end
  end


  @doc false
  def handle_buffer(:sink, %Membrane.Caps.Audio.Opus{}, %Membrane.Buffer{payload: payload}, %{native: native, fec: fec, queue: queue} = state) do
    # {:ok, {decoded_data, decoded_channels}} = DecoderNative.decoder_int(native, data, fec)

    # {:send_buffer, {%Membrane.Caps{content: "audio/x-raw", channels: decoded_channels}, decoded_data}

    {:ok, state} # TODO
  end
end
