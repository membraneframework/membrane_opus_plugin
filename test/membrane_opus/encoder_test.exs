defmodule Membrane.Opus.Encoder.EncoderTest do
  use ExUnit.Case, async: true

  alias Membrane.Opus.{Encoder, Decoder}
  alias Membrane.Caps.Audio.Raw
  import Membrane.Testing.Assertions
  alias Membrane.Testing
  alias Membrane.Element.File
  import Membrane.ParentSpec

  @input_path "test/fixtures/raw_packets"

  setup do
    elements = [
      source: %File.Source{
        location: @input_path
      },
      encoder: %Encoder{
        application: :audio,
        input_caps: %Raw{
          channels: 2,
          format: :s16le,
          sample_rate: 48_000
        }
      },
      decoder: %Decoder{
        sample_rate: 48_000,
        channels: 2
      },
      sink: Testing.Sink
    ]

    links = [
      link(:source)
      |> to(:encoder)
      |> to(:decoder)
      |> to(:sink)
    ]

    {:ok, pipeline_pid} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements,
        links: links
      })

    {:ok, %{pipeline_pid: pipeline_pid}}
  end

  # NOTE: a full integration test of Opus will require implementation of an
  # Opus container and parser. The libopus encoder tests do the same thing
  # we're doing here: just ensuring that encoded packets can be decoded.
  #
  # https://gitlab.xiph.org/xiph/opus/-/blob/master/tests/test_opus_encode.c#L160
  test "eating our own dog food", context do
    %{pipeline_pid: pipeline_pid} = context
    Membrane.Pipeline.play(pipeline_pid)
    assert_start_of_stream(pipeline_pid, :sink)
    assert_end_of_stream(pipeline_pid, :sink)
  end
end
