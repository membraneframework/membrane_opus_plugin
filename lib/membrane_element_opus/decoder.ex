defmodule Membrane.Element.Opus.Decoder do
  @moduledoc """
  This element performs decoding of Opus audio.
  """

  alias Membrane.Buffer
  alias Membrane.Element.Opus.Decoder.Native
  alias Membrane.Event.Discontinuity
  alias Membrane.Caps.Audio.{Opus, Raw}

  use Membrane.Filter

  def_options sample_rate: [
                spec: 8000 | 12000 | 16000 | 24000 | 48000,
                default: 48000
              ],
              channels: [
                spec: 1 | 2,
                default: 2
              ],
              enable_fec: [
                spec: boolean(),
                default: true
              ],
              enable_plc: [
                spec: boolean(),
                default: true
              ]

  def_input_pad :input,
    # {Opus, channels: 2},
    caps: :any,
    demand_unit: :buffers

  def_output_pad :output,
    caps: {Raw, format: :s16le}

  @impl true
  def handle_init(%__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.put(:missed_a_packet, false)

    {:ok, state}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, state) do
    Native.create(state.sample_rate, state.channels)
    |> case do
      {:ok, decoder} ->
        state = Map.put(state, :native, decoder)
        {:ok, state}

      {:error, cause} ->
        {{:error, cause}, state}
    end
  end

  @impl true
  def handle_event(
        :input,
        %Discontinuity{} = event,
        _context,
        %{enable_plc: true, enable_fec: false} = state
      ) do
    duration = Native.get_last_packet_duration(state.native)
    {:ok, decoded} = Native.decode_packet(state.native, <<>>, 1, duration)

    {{:ok, event: {:output, event}}, state}
  end

  @impl true
  def handle_event(
        :input,
        %Discontinuity{},
        _context,
        %{enable_plc: true, enable_fec: true, missed_a_packet: true} = state
      ) do
    duration = Native.get_last_packet_duration(state.native)
    {:ok, decoded} = Native.decode_packet(state.native, <<>>, 1, duration)

    {{:ok, buffer: {:output, %Buffer{payload: decoded}}}, state}
  end

  @impl true
  def handle_event(:input, %Discontinuity{} = event, _context, state) do
    {{:ok, event: {:output, event}}, state}
  end

  @impl true
  def handle_process(
        :input,
        buffer,
        _context,
        %{missed_a_packet: true, enable_fec: true, duration: duration} = state
      ) do
    {:ok, old_packet} = Native.decode_packet(state.native, buffer.payload, 1, duration)
    {:ok, fresh_packet} = Native.decode_packet(state.native, buffer.payload, 0, duration)
    old_buffer = %Buffer{payload: old_packet}
    fresh_buffer = %{buffer | payload: fresh_packet}

    {{:ok, buffer: {:output, [old_buffer, fresh_buffer]}}, %{state | missed_a_packet: false}}
  end

  @impl true
  def handle_process(:input, buffer, context, state) do
    # TODO this makes decode_packet sysfault
    # duration = Native.get_last_packet_duration(state.native)
    # duration = if duration == 0, do: 20, else: 120
    duration = 20
    {:ok, decoded} = Native.decode_packet(state.native, buffer.payload, 0, duration)
    duration = Native.get_last_packet_duration(state.native)

    buffer = Map.put(buffer, :payload, decoded)

    {{:ok, buffer: {:output, buffer}}, state}
  end

  @impl true
  def handle_demand(pad, size, unit, context, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    :ok = Native.destroy(state.native)
    {:ok, state}
  end
end
