defmodule Membrane.Opus.Parser.ParserTest do
  use ExUnit.Case, async: true

  import Membrane.Time
  import Membrane.Testing.Assertions

  alias Membrane.Opus.Parser
  alias Membrane.{Opus, Buffer}
  alias Membrane.Testing.{Source, Sink, Pipeline}

  test "non-self-delimiting" do
    inputs_and_expectations = [
      {
        # dropped packet, code 0
        <<4>>,
        %Opus{
          channels: 2,
          self_delimiting?: false
        },
        %{
          duration: 0
        }
      },
      {
        # code 1
        <<121, 0, 0, 0, 0>>,
        %Opus{
          channels: 1,
          self_delimiting?: false
        },
        %{
          duration: 40 |> milliseconds()
        }
      },
      {
        # code 2
        <<198, 1, 0, 0, 0, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: false
        },
        %{
          duration: 5 |> milliseconds()
        }
      },
      {
        # code 3 cbr - no padding
        <<199, 3, 0, 0, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: false
        },
        %{
          duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
        }
      },
      {
        # code 3 cbr - padding
        <<199, 67, 2, 0, 0, 0, 0, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: false
        },
        %{
          duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
        }
      },
      {
        # code 3 vbr - no padding
        <<199, 131, 1, 2, 0, 0, 0, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: false
        },
        %{
          duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
        }
      },
      {
        # code 3 vbr - no padding, long length
        <<199, 131, 253, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
          0, 3, 3, 3>>,
        %Opus{
          channels: 2,
          self_delimiting?: false
        },
        %{
          duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
        }
      }
    ]

    inputs =
      inputs_and_expectations
      |> Enum.map(fn {input, _caps, _meta} -> input end)

    options = %Pipeline.Options{
      elements: [
        source: %Source{output: inputs},
        parser: Parser,
        sink: Sink
      ]
    }

    {:ok, pipeline} = Pipeline.start_link(options)
    Pipeline.play(pipeline)

    assert_start_of_stream(pipeline, :sink)

    inputs_and_expectations
    |> Enum.each(fn {input, caps, meta} ->
      assert_sink_caps(pipeline, :sink, ^caps)
      assert_sink_buffer(pipeline, :sink, %Buffer{payload: ^input, metadata: ^meta})
    end)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
  end

  test "self-delimiting" do
    inputs_and_expectations = [
      {
        # dropped packet, code 0
        <<4>>,
        <<4, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: true
        },
        %{
          duration: 0
        }
      },
      {
        # code 1
        <<121, 0, 0, 0, 0>>,
        <<121, 2, 0, 0, 0, 0>>,
        %Opus{
          channels: 1,
          self_delimiting?: true
        },
        %{
          duration: 40 |> milliseconds()
        }
      },
      {
        # code 2
        <<198, 1, 0, 0, 0, 0>>,
        <<198, 1, 3, 0, 0, 0, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: true
        },
        %{
          duration: 5 |> milliseconds()
        }
      },
      {
        # code 3 cbr - no padding
        <<199, 3, 0, 0, 0>>,
        <<199, 3, 1, 0, 0, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: true
        },
        %{
          duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
        }
      },
      {
        # code 3 cbr - padding
        <<199, 67, 2, 0, 0, 0, 0, 0>>,
        <<199, 67, 2, 1, 0, 0, 0, 0, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: true
        },
        %{
          duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
        }
      },
      {
        # code 3 vbr - no padding
        <<199, 131, 1, 2, 0, 0, 0, 0>>,
        <<199, 131, 1, 2, 1, 0, 0, 0, 0>>,
        %Opus{
          channels: 2,
          self_delimiting?: true
        },
        %{
          duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
        }
      },
      {
        # code 3 vbr - no padding, long length
        <<199, 131, 253, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
          0, 3, 3, 3>>,
        <<199, 131, 253, 0, 2, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          0, 0, 3, 3, 3>>,
        %Opus{
          channels: 2,
          self_delimiting?: true
        },
        %{
          duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
        }
      }
    ]

    inputs =
      inputs_and_expectations
      |> Enum.map(fn {input, _output, _caps, _meta} -> input end)

    options = %Pipeline.Options{
      elements: [
        source: %Source{output: inputs},
        parser: %Parser{self_delimit?: true},
        sink: Sink
      ]
    }

    {:ok, pipeline} = Pipeline.start_link(options)
    Pipeline.play(pipeline)

    assert_start_of_stream(pipeline, :sink)

    inputs_and_expectations
    |> Enum.each(fn {_input, output, caps, meta} ->
      assert_sink_caps(pipeline, :sink, ^caps)
      assert_sink_buffer(pipeline, :sink, %Buffer{payload: ^output, metadata: ^meta})
    end)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
  end
end
