defmodule Membrane.Opus.Encoder.EncoderTest do
  use ExUnit.Case, async: true

  alias Membrane.Opus.Encoder
  alias Membrane.Opus.Support.Reader
  alias Membrane.Caps.Audio.Raw
  import Membrane.Testing.Assertions
  alias Membrane.Testing
  alias Membrane.Element.File
  import Membrane.ParentSpec

  @in_path "input.wav"
  @sample_opus Reader.read_packets("test/fixtures/opus_packets")

  setup do
    elements = [
      source: %File.Source{
        location: @in_path
      },
      opus: %Encoder{
        application: :audio,
        channels: 2,
        input_caps: %Raw{
          channels: 2,
          format: :s16le,
          sample_rate: 48_000
        }
      },
      sink: %File.Sink{location: "output.opus"}
    ]

    links = [link(:source) |> to(:opus) |> to(:sink)]

    {:ok, pipeline_pid} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements,
        links: links
      })

    {:ok, pipeline_pid: pipeline_pid}
  end

  test "integration", state do
    assert :ok = Membrane.Pipeline.play(state[:pipeline_pid])
    assert_start_of_stream(state[:pipeline_pid], :sink)

    assert_end_of_stream(state[:pipeline_pid], :sink)
  end
end
