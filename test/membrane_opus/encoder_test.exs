defmodule Membrane.Opus.Encoder.EncoderTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions

  alias Membrane.Opus.Encoder
  alias Membrane.RawAudio
  alias Membrane.Testing

  @input_path "test/fixtures/raw_packets"
  @output_path "test/fixtures/encoder_output"
  @reference_path "test/fixtures/encoder_output_reference"

  setup do
    on_exit(fn -> File.rm(@output_path) end)

    elements = [
      source: %Membrane.File.Source{
        location: @input_path
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
