defmodule Membrane.Opus.Decoder.DecoderTest do
  use ExUnit.Case, async: true

  alias Membrane.Opus.Decoder
  alias Membrane.Opus.Support.Reader
  alias Membrane.RemoteStream

  @sample_opus_packets Reader.read_packets("test/fixtures/decoder_output_reference")
  @sample_raw Reader.read_packets("test/fixtures/raw_packets")

  test "integration" do
    import Membrane.ParentSpec
    import Membrane.Testing.Assertions
    alias Membrane.Testing

    elements = [
      source: %Testing.Source{
        output: @sample_opus_packets,
        caps: %RemoteStream{type: :packetized}
      },
      opus: Decoder,
      sink: Testing.Sink
    ]

    links = [link(:source) |> to(:opus) |> to(:sink)]

    {:ok, pipeline} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements,
        links: links
      })

    assert_start_of_stream(pipeline, :sink)

    Enum.each(@sample_raw, fn expected_payload ->
      assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{payload: payload})
      assert payload == expected_payload
    end)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)

    Membrane.Pipeline.terminate(pipeline, blocking?: true)
  end
end
