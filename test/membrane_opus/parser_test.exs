defmodule Membrane.Opus.Parser.ParserTest do
  use ExUnit.Case, async: true

  import Membrane.Time
  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  alias Membrane.Opus.Parser
  alias Membrane.RemoteStream
  alias Membrane.{Buffer, Opus}
  alias Membrane.Testing.{Pipeline, Sink, Source}

  @fixtures [
    %{
      desc: "dropped packet, code 0",
      normal: <<4>>,
      delimited: <<4, 0>>,
      channels: 2,
      duration: 10 |> milliseconds(),
      pts: 0
    },
    %{
      desc: "code 1",
      normal: <<121, 0, 0, 0, 0>>,
      delimited: <<121, 2, 0, 0, 0, 0>>,
      channels: 1,
      duration: 40 |> milliseconds(),
      pts: 10 |> milliseconds()
    },
    %{
      desc: "code 2",
      normal: <<198, 1, 0, 0, 0, 0>>,
      delimited: <<198, 1, 3, 0, 0, 0, 0>>,
      channels: 2,
      duration: 5 |> milliseconds(),
      pts: 50 |> milliseconds()
    },
    %{
      desc: "code 3 cbr, no padding",
      normal: <<199, 3, 0, 0, 0>>,
      delimited: <<199, 3, 1, 0, 0, 0>>,
      channels: 2,
      duration: (2.5 * 3 * 1_000_000) |> trunc() |> nanoseconds(),
      pts: 55 |> milliseconds()
    },
    %{
      desc: "code 3 cbr, padding",
      normal: <<199, 67, 2, 0, 0, 0, 0, 0>>,
      delimited: <<199, 67, 2, 1, 0, 0, 0, 0, 0>>,
      channels: 2,
      duration: (2.5 * 3 * 1_000_000) |> trunc() |> nanoseconds(),
      pts: (62.5 * 1_000_000) |> trunc() |> nanoseconds()
    },
    %{
      desc: "code 3 vbr, no padding",
      normal: <<199, 131, 1, 2, 0, 0, 0, 0>>,
      delimited: <<199, 131, 1, 2, 1, 0, 0, 0, 0>>,
      channels: 2,
      duration: (2.5 * 3 * 1_000_000) |> trunc() |> nanoseconds(),
      pts: 70 |> milliseconds()
    },
    %{
      desc: "code 3 vbr, no padding, long length",
      normal:
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
      delimited:
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
      channels: 2,
      duration: (2.5 * 3 * 1_000_000) |> trunc() |> nanoseconds(),
      pts: (77.5 * 1_000_000) |> trunc() |> nanoseconds()
    }
  ]

  defp buffers_from_fixtures(
         fixtures,
         self_delimited? \\ false,
         generate_best_effort_timestamps? \\ false
       ) do
    Enum.map(fixtures, fn fixture ->
      %Buffer{
        pts:
          if generate_best_effort_timestamps? do
            nil
          else
            fixture.pts
          end,
        payload:
          if self_delimited? do
            fixture.delimited
          else
            fixture.normal
          end
      }
    end)
  end

  test "non-self-delimiting input and output" do
    spec = [
      child(:source, %Source{
        output: buffers_from_fixtures(@fixtures),
        stream_format: %RemoteStream{type: :bytestream}
      })
      |> child(:parser, Parser)
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, false)
  end

  test "non-self-delimiting input, self-delimiting output" do
    spec = [
      child(:source, %Source{
        output: buffers_from_fixtures(@fixtures),
        stream_format: %RemoteStream{type: :bytestream}
      })
      |> child(:parser, %Parser{delimitation: :delimit})
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, true)
  end

  test "self-delimiting input and output" do
    spec = [
      child(:source, %Source{
        output: buffers_from_fixtures(@fixtures, true),
        stream_format: %RemoteStream{type: :bytestream}
      })
      |> child(:parser, %Parser{input_delimitted?: true})
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, true)
  end

  test "self-delimiting input, non-self-delimiting output" do
    spec = [
      child(:source, %Source{
        output: buffers_from_fixtures(@fixtures, true),
        stream_format: %RemoteStream{type: :bytestream}
      })
      |> child(:parser, %Parser{delimitation: :undelimit, input_delimitted?: true})
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)
    do_test(pipeline, false)
  end

  test "non-self-delimiting input and output, generate_best_effort_timestamps?" do
    spec =
      child(:source, %Source{
        output: buffers_from_fixtures(@fixtures, false, true),
        stream_format: %RemoteStream{type: :bytestream}
      })
      |> child(:parser, %Parser{generate_best_effort_timestamps?: true})
      |> child(:sink, Sink)

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, false)
  end

  test "non-self-delimiting input, self-delimiting output, generate_best_effort_timestamps?" do
    spec = [
      child(:source, %Source{
        output: buffers_from_fixtures(@fixtures, false, true),
        stream_format: %RemoteStream{type: :bytestream}
      })
      |> child(:parser, %Parser{delimitation: :delimit, generate_best_effort_timestamps?: true})
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, true)
  end

  test "self-delimiting input and output, generate_best_effort_timestamps?" do
    spec = [
      child(:source, %Source{
        output: buffers_from_fixtures(@fixtures, true, true),
        stream_format: %RemoteStream{type: :bytestream}
      })
      |> child(:parser, %Parser{input_delimitted?: true, generate_best_effort_timestamps?: true})
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, true)
  end

  test "self-delimiting input, non-self-delimiting output, generate_best_effort_timestamps?" do
    spec = [
      child(:source, %Source{
        output: buffers_from_fixtures(@fixtures, true, true),
        stream_format: %RemoteStream{type: :bytestream}
      })
      |> child(:parser, %Parser{
        delimitation: :undelimit,
        input_delimitted?: true,
        generate_best_effort_timestamps?: true
      })
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, false)
  end

  defp do_test(pipeline, self_delimiting?) do
    assert_start_of_stream(pipeline, :sink)

    @fixtures
    |> Enum.each(fn fixture ->
      expected_buffer = %Buffer{
        pts: fixture.pts,
        payload: if(self_delimiting?, do: fixture.delimited, else: fixture.normal),
        metadata: %{duration: fixture.duration}
      }

      assert_sink_buffer(pipeline, :sink, ^expected_buffer, 4000)
    end)

    refute_sink_buffer(pipeline, :sink, _, 0)

    @fixtures
    |> Enum.map(& &1.channels)
    |> then(&Enum.zip([nil | &1], &1))
    |> Enum.reject(fn {a, b} -> a == b end)
    |> Enum.each(fn {_old_channels, new_channels} ->
      assert_sink_stream_format(
        pipeline,
        :sink,
        %Opus{channels: ^new_channels, self_delimiting?: ^self_delimiting?},
        0
      )
    end)

    refute_sink_stream_format(pipeline, :sink, 0)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)

    Pipeline.terminate(pipeline)
  end
end
