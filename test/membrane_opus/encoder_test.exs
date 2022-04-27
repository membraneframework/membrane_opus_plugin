defmodule Membrane.Opus.Encoder.EncoderTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions

  alias Membrane.Opus.Encoder
  alias Membrane.RawAudio
  alias Membrane.Testing

  defmodule CapsProvider do
    @moduledoc false
    use Membrane.Filter

    def_options input_caps: [
                  description:
                    "Caps which will be sent on the :output pad once the :input pad receives any caps",
                  type: :caps
                ]

    def_output_pad :output, demand_mode: :auto, caps: :any

    def_input_pad :input, demand_unit: :bytes, demand_mode: :auto, caps: :any

    @impl true
    def handle_init(opts) do
      {:ok, %{caps: opts.input_caps}}
    end

    @impl true
    def handle_caps(:input, _caps, _ctx, state) do
      {{:ok, caps: {:output, state.caps}}, state}
    end

    @impl true
    def handle_process(:input, buffer, _ctx, state) do
      {{:ok, buffer: {:output, buffer}}, state}
    end
  end

  @input_path "test/fixtures/raw_packets"
  @output_path "test/fixtures/encoder_output"
  @reference_path "test/fixtures/encoder_output_reference"

  setup do
    on_exit(fn -> File.rm(@output_path) end)

    elements = [
      source: %Membrane.File.Source{
        location: @input_path
      },
      caps_provider: %CapsProvider{
        input_caps: %RawAudio{
          channels: 2,
          sample_format: :s16le,
          sample_rate: 48_000
        }
      },
      encoder: %Encoder{
        application: :audio,
        input_caps: %RawAudio{
          channels: 2,
          sample_format: :s16le,
          sample_rate: 48_000
        }
      },
      sink: %Membrane.File.Sink{
        location: @output_path
      }
    ]

    {:ok, pipeline_pid} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements
      })

    {:ok, %{pipeline_pid: pipeline_pid}}
  end

  test "encoded output matches reference", context do
    %{pipeline_pid: pipeline_pid} = context
    assert_start_of_stream(pipeline_pid, :sink)
    assert_end_of_stream(pipeline_pid, :sink, _, 5000)

    reference = File.read!(@reference_path)
    output = File.read!(@output_path)
    assert reference == output

    Membrane.Pipeline.terminate(pipeline_pid, blocking?: true)
  end
end
