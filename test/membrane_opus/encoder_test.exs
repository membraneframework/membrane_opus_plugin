defmodule Membrane.Opus.Encoder.EncoderTest do
  use ExUnit.Case, async: true

  alias Membrane.Opus
  alias Membrane.Caps.Audio.Raw
  import Membrane.Testing.Assertions
  alias Membrane.Testing
  import Membrane.ParentSpec

  @input_path "test/fixtures/sample_input.raw"
  @output_path "test/fixtures/encoder_output.opus"
  @reference_path "test/fixtures/encoder_output_reference.opus"

  setup do
    on_exit(fn -> File.rm(@output_path) end)

    elements = [
      source: %Membrane.File.Source{location: @input_path},
      encoder: %Opus.Encoder{
        application: :audio,
        input_caps: %Raw{
          channels: 2,
          format: :s16le,
          sample_rate: 48_000
        }
      },
      serializer: Opus.Serializer,
      sink: %Membrane.File.Sink{location: @output_path}
    ]

    links = [
      link(:source)
      |> to(:encoder)
      |> to(:serializer)
      |> to(:sink)
    ]

    {:ok, pipeline_pid} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements,
        links: links
      })

    {:ok, %{pipeline_pid: pipeline_pid}}
  end

  test "encoded output matches reference", context do
    %{pipeline_pid: pipeline_pid} = context
    Membrane.Pipeline.play(pipeline_pid)
    assert_start_of_stream(pipeline_pid, :sink)
    assert_end_of_stream(pipeline_pid, :sink, _, 5000)

    reference = File.read!(@reference_path)
    output = File.read!(@output_path)
    assert reference == output
  end
end
