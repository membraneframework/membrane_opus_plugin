defmodule Membrane.Opus.Encoder.EncoderTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  alias Membrane.Opus.Encoder
  alias Membrane.RawAudio
  alias Membrane.Testing.{Pipeline, Sink}

  @input_path "test/fixtures/raw_packets"
  @reference_path "test/fixtures/encoder_output_reference"

  defp setup_pipeline(output_path) do
    spec = [
      child(:source, %Membrane.File.Source{
        location: @input_path
      })
      |> child(:encoder, %Encoder{
        application: :audio,
        input_stream_format: %RawAudio{
          channels: 2,
          sample_format: :s16le,
          sample_rate: 48_000
        }
      })
      |> child(:sink, %Membrane.File.Sink{
        location: output_path
      })
    ]

    Pipeline.start_link_supervised!(spec: spec)
  end

  @tag :tmp_dir
  test "encoded output matches reference", %{tmp_dir: tmp_dir} do
    output_path = Path.join(tmp_dir, "encoder_output")
    pipeline_pid = setup_pipeline(output_path)
    assert_start_of_stream(pipeline_pid, :sink)
    assert_end_of_stream(pipeline_pid, :sink, _, 5000)

    reference = File.read!(@reference_path)
    output = File.read!(output_path)
    assert reference == output

    Membrane.Pipeline.terminate(pipeline_pid)
  end

  test "encoder works with stream format received on :input pad" do
    spec = [
      child(:source, %Membrane.File.Source{
        location: @input_path
      })
      |> child(:parser, %Membrane.RawAudioParser{
        stream_format: %Membrane.RawAudio{channels: 2, sample_format: :s16le, sample_rate: 48_000}
      })
      |> child(:encoder, Encoder)
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)
    assert_start_of_stream(pipeline, :encoder, :input)

    Pipeline.terminate(pipeline)
  end
end
