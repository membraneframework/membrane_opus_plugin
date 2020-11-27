defmodule Membrane.Opus.Decoder.DecoderTest do
  use ExUnit.Case, async: true

  alias Membrane.Opus
  alias Membrane.Opus.Support.Reader

  @sample_opus_packets Reader.read_packets("test/fixtures/decoder_output_reference_packets")
  @sample_raw_packets Reader.read_packets("test/fixtures/raw_packets")

  @sample_path "test/fixtures/encoder_output_reference.opus"
  @output_path "test/fixtures/decoder_output.raw"
  @reference_path "test/fixtures/decoder_output_reference.raw"

  test "sample packets" do
    import Membrane.ParentSpec
    import Membrane.Testing.Assertions
    alias Membrane.Testing

    elements = [
      source: %Testing.Source{
        output: @sample_opus_packets
      },
      opus: Opus.Decoder,
      sink: Testing.Sink
    ]

    links = [link(:source) |> to(:opus) |> to(:sink)]

    {:ok, pipeline} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements,
        links: links
      })

    Membrane.Pipeline.play(pipeline)
    assert_start_of_stream(pipeline, :sink)

    Enum.each(@sample_raw_packets, fn expected_payload ->
      assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{payload: payload})
      assert payload == expected_payload
    end)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
  end

  test "sample file" do
    on_exit(fn -> File.rm(@output_path) end)

    import Membrane.ParentSpec
    import Membrane.Testing.Assertions
    alias Membrane.Testing

    elements = [
      source: %Membrane.File.Source{location: @sample_path},
      parser: Opus.Parser,
      decoder: Opus.Decoder,
      sink: %Membrane.File.Sink{location: @output_path}
    ]

    links = [link(:source) |> to(:parser) |> to(:decoder) |> to(:sink)]

    {:ok, pipeline} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements,
        links: links
      })

    Membrane.Pipeline.play(pipeline)
    assert_start_of_stream(pipeline, :sink)
    assert_end_of_stream(pipeline, :sink)
    reference = File.read!(@reference_path)
    output = File.read!(@output_path)
    assert reference == output
  end
end
