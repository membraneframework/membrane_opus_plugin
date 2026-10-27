defmodule Membrane.Opus.Encoder.Native.NativeTest do
  use ExUnit.Case, async: true

  alias Membrane.Opus.Encoder.Native

  test "encode_packet rejects payloads shorter than frame_size * channels" do
    state = Native.create(48_000, 2, 2048, -1000, -1000)
    frame_size = 960

    for payload <- [<<>>, :binary.copy(<<0>>, frame_size * 2 * 2 - 1)] do
      assert {:error, :invalid_frame_size} = Native.encode_packet(state, payload, frame_size)
    end

    assert {:ok, _packet} =
             Native.encode_packet(state, :binary.copy(<<0>>, frame_size * 2 * 2), frame_size)
  end
end
