defmodule Membrane.Opus.Encoder.EncoderTest do
  use ExUnit.Case, async: true

  alias Membrane.Opus.{Encoder, Decoder}
  alias Membrane.Caps.Audio.Raw
  import Membrane.Testing.Assertions
  alias Membrane.Testing
  alias Membrane.Element
  import Membrane.ParentSpec
  alias Membrane.Opus.Support.Reader

  @input_path "test/fixtures/encoder_input.wav"
  @output_path "test/fixtures/encoder_output.opus"
  @reference_path "test/fixtures/encoder_output_reference.opus"

  setup do
    elements = [
      source: %Element.File.Source{
        location: @input_path
      },
      encoder: %Encoder{
        application: :low_delay,
        input_caps: %Raw{
          channels: 2,
          format: :s16le,
          sample_rate: 48_000
        }
      },
      sink: %Element.File.Sink{
        location: @output_path
      }
    ]

    links = [
      link(:source)
      |> to(:encoder)
      |> to(:sink)
    ]

    {:ok, pipeline_pid} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements,
        links: links
      })

    on_exit(fn -> File.rm(@output_path) end)

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
    assert_end_of_stream(pipeline_pid, :sink, _, 5000)

    reference = File.read!(@reference_path)
    output = File.read!(@output_path)
    assert reference == output
  end
end
