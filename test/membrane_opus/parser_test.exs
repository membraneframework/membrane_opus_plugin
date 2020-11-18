defmodule Membrane.Opus.Parser.ParserTest do
  use ExUnit.Case, async: true

  alias Membrane.Element
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Testing
  alias Membrane.Opus.{Encoder, Parser}
  import Membrane.ParentSpec
  import Membrane.Testing.Assertions

  @input_path "/Users/gweisbrod/Desktop/input.wav"
  @output_path "/Users/gweisbrod/Desktop/example.opus"

  setup do
    elements = [
      source: %Element.File.Source{
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
      parser: Parser,
      payloader: Membrane.Ogg.Payloader.Opus,
      sink: %Element.File.Sink{
        location: @output_path
      }
    ]

    links = [
      link(:source)
      |> to(:encoder)
      |> to(:parser)
      |> to(:payloader)
      |> to(:sink)
    ]

    {:ok, pipeline_pid} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        elements: elements,
        links: links
      })

    {:ok, %{pipeline_pid: pipeline_pid}}
  end

  test "practice", context do
    %{pipeline_pid: pipeline_pid} = context
    Membrane.Pipeline.play(pipeline_pid)
    assert_start_of_stream(pipeline_pid, :sink)
    assert_end_of_stream(pipeline_pid, :sink, _, 5000)
  end
end
