defmodule Membrane.Element.Opus.Decoder do
  @moduledoc """
  This element performs decoding of Opus audio.
  """

  use Membrane.Element.Base.Filter
  alias Membrane.Element.Opus.DecoderNative
  alias Membrane.Element.Opus.DecoderOptions
  use Membrane.Mixins.Log

  # TODO support float samples
  def_known_source_pads %{
    :source => {:always, [
      %Membrane.Caps.Audio.Raw{sample_rate: 48000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 24000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 16000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 12000, format: :s16le},
      %Membrane.Caps.Audio.Raw{sample_rate: 8000,  format: :s16le},
    ]}
  }

  def_known_sink_pads %{
    :sink => {:always, [
      %Membrane.Caps.Audio.Opus{},
    ]}
  }


  # Private API

  @doc false
  def handle_init(%DecoderOptions{sample_rate: sample_rate, channels: channels, enable_fec: enable_fec, enable_plc: enable_plc}) do
    {:ok, %{
      enable_fec: enable_fec,
      enable_plc: enable_plc,
      sample_rate: sample_rate,
      channels: channels,
      native: nil,
      prev_payload: nil,
      prev_frame_duration: nil,
    }}
  end


  @doc false
  def handle_prepare(_prev_state, %{sample_rate: sample_rate, channels: channels} = state) do
    case DecoderNative.create(sample_rate,  channels) do
      {:ok, native} ->
        command = [{:caps, {:source, %Membrane.Caps.Audio.Raw{sample_rate: sample_rate, channels: channels, format: :s16le}}}]
        {:ok, command, %{state | native: native}}

      {:error, reason} ->
        {:error, reason, %{state | native: nil}}
    end
  end


  # Handling buffer when FEC is disabled
  @doc false
  def handle_buffer(:sink, %Membrane.Caps.Audio.Opus{frame_duration: frame_duration}, %Membrane.Buffer{payload: payload}, %{native: native,  enable_fec: false} = state) do
    {:ok, decoded_data} = DecoderNative.decode_int(native, payload, 0, frame_duration)
    {:ok, [{:send, {:source, %Membrane.Buffer{payload: decoded_data}}}], state}
  end


  # Handling buffer when FEC in enabled
  # It stores previous frame in element's state and adds additional delay of one
  # opus frame
  @doc false
  def handle_buffer(:sink, %Membrane.Caps.Audio.Opus{frame_duration: frame_duration}, %Membrane.Buffer{payload: payload}, %{native: native, prev_frame_duration: prev_frame_duration, prev_payload: prev_payload, enable_fec: true} = state) do

    decoded_data = case {prev_payload, prev_frame_duration} do
      # first buffer. delay by one packet
      {nil, nil} ->
        nil

      # previous frame is missing
      # use FEC
      {nil, _} ->
        {:ok, decoded_data} = DecoderNative.decode_int(native, payload, 1, prev_frame_duration)
        decoded_data

      # previous frame is present
      # regular decode
      _ ->
        {:ok, decoded_data} = DecoderNative.decode_int(native, prev_payload, 0, prev_frame_duration)
        decoded_data
    end

    case decoded_data do
      nil ->
        {:ok, %{state | prev_payload: payload, prev_frame_duration: frame_duration}}
      _ ->
        {:ok, [{:send, {:source, %Membrane.Buffer{payload: decoded_data}}}], %{state | prev_frame_duration: frame_duration, prev_payload: payload}}
    end

  end


  # Handling discontinuity when FEC is disabled.
  # Use PLC if enabled, otherwise forward the discontinuity event
  @doc false
  def handle_event(:sink, %Membrane.Caps.Audio.Opus{}, %Membrane.Event{type: :discontinuity, payload: %{duration: duration}} = event, %{native: native, enable_fec: false, enable_plc: enable_plc} = state) do
    case enable_plc do
      true ->
        {:ok, decoded_data} = DecoderNative.decode_int(native, <<>>, 1, duration |> native_to_ms)
        {:ok, [{:send, {:source, %Membrane.Buffer{payload: decoded_data}}}], state}
      false ->
        {:ok, [{:send, {:source, event}}], state}
    end
  end


  # Handling discontinuity when FEC is enabled
  @doc false
  def handle_event(:sink, %Membrane.Caps.Audio.Opus{}, %Membrane.Event{type: :discontinuity, payload: %{duration: duration}} = event, %{native: native, prev_payload: prev_payload, prev_frame_duration: prev_frame_duration, enable_fec: true} = state) do

    decoded_data = case {prev_payload, prev_frame_duration} do

      # received discontinuity before any valid frame
      # just forward the event
      {nil, nil} ->
        nil

      # both actual and previous frames are missing
      # use PLC (it must be enabled when FEC is enabled)
      {nil, _} ->
        {:ok, decoded_data} = DecoderNative.decode_int(native, <<>>, 1, prev_frame_duration)
        decoded_data

      # previous frame is present
      # regular decode
      _ ->
        {:ok, decoded_data} = DecoderNative.decode_int(native, prev_payload, 0, prev_frame_duration)
        decoded_data
    end

    case decoded_data do
      nil ->
        {:ok, [{:send, {:source, event}}], state}
      _ ->
        {:ok, [{:send, {:source, %Membrane.Buffer{payload: decoded_data}}}], %{state | prev_frame_duration: duration |> native_to_ms, prev_payload: nil}}
    end
  end


  defp native_to_ms(val), do: val / 1_000_000 |> trunc
end
