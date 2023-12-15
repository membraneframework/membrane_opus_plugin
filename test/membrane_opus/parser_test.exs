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
      duration: 0,
      pts: 0
    },
    %{
      desc: "code 1",
      normal: <<121, 0, 0, 0, 0>>,
      delimited: <<121, 2, 0, 0, 0, 0>>,
      channels: 1,
      duration: 40 |> milliseconds(),
      pts: 0
    },
    %{
      desc: "code 2",
      normal: <<198, 1, 0, 0, 0, 0>>,
      delimited: <<198, 1, 3, 0, 0, 0, 0>>,
      channels: 2,
      duration: 5 |> milliseconds(),
      pts: 40 |> milliseconds()
    },
    %{
      desc: "code 3 cbr, no padding",
      normal: <<199, 3, 0, 0, 0>>,
      delimited: <<199, 3, 1, 0, 0, 0>>,
      channels: 2,
      duration: (2.5 * 3 * 1_000_000) |> trunc() |> nanoseconds(),
      pts: 45 |> milliseconds()
    },
    %{
      desc: "code 3 cbr, padding",
      normal: <<199, 67, 2, 0, 0, 0, 0, 0>>,
      delimited: <<199, 67, 2, 1, 0, 0, 0, 0, 0>>,
      channels: 2,
      duration: (2.5 * 3 * 1_000_000) |> trunc() |> nanoseconds(),
      pts: (52.5 * 1_000_000) |> trunc() |> nanoseconds()
    },
    %{
      desc: "code 3 vbr, no padding",
      normal: <<199, 131, 1, 2, 0, 0, 0, 0>>,
      delimited: <<199, 131, 1, 2, 1, 0, 0, 0, 0>>,
      channels: 2,
      duration: (2.5 * 3 * 1_000_000) |> trunc() |> nanoseconds(),
      pts: 60 |> milliseconds()
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
      pts: (67.5 * 1_000_000) |> trunc() |> nanoseconds()
    }
  ]
  test "non-self-delimiting input and output" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> fixture.normal end)

    spec = [
      child(:source, %Source{output: inputs, stream_format: %RemoteStream{type: :bytestream}})
      |> child(:parser, Parser)
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, false)
  end

  test "non-self-delimiting input, self-delimiting output" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> fixture.normal end)

    spec = [
      child(:source, %Source{output: inputs, stream_format: %RemoteStream{type: :bytestream}})
      |> child(:parser, %Parser{delimitation: :delimit, generate_best_effort_timestamps: true})
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, true)
  end

  test "self-delimiting input and output" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> fixture.delimited end)

    spec = [
      child(:source, %Source{output: inputs, stream_format: %RemoteStream{type: :bytestream}})
      |> child(:parser, %Parser{input_delimitted?: true, generate_best_effort_timestamps: true})
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, true)
  end

  test "self-delimiting input, non-self-delimiting output" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> fixture.delimited end)

    spec = [
      child(:source, %Source{output: inputs, stream_format: %RemoteStream{type: :bytestream}})
      |> child(:parser, %Parser{
        delimitation: :undelimit,
        input_delimitted?: true,
        generate_best_effort_timestamps: true
      })
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, false)
  end

  test "self-delimiting input, multiple self-delimiting outputs" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> %Membrane.Buffer{payload: fixture.delimited, pts: fixture.pts} end)

    spec = [
      child(:source, %Source{output: inputs, stream_format: %RemoteStream{type: :bytestream}})
      |> child(:parser, %Parser{input_delimitted?: true, generate_best_effort_timestamps: false})
      |> child(:sink, Sink)
    ]

    pipeline = Pipeline.start_link_supervised!(spec: spec)

    do_test(pipeline, true)
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

    refute_sink_buffer(pipeline, :sink, 0)

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
