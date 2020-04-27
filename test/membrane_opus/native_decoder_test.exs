defmodule Membrane.Opus.Decoder.Native.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Opus.Decoder.Native
  alias Membrane.Opus.Support.Reader

  @sample_opus_packets Reader.read_packets("test/fixtures/opus_packets")
  @sample_raw Reader.read_packets("test/fixtures/raw_packets")

  test "Native decoder creation/destruction works" do
    assert {:ok, state} = Native.create(24000, 1)
    assert {:ok, state} = Native.create(48000, 2)
  end

  describe "Native decoder" do
    setup do
      {:ok, state} = Native.create(48000, 2)
      %{state: state}
    end

    test "decodes opus packets", %{state: state} do
      @sample_opus_packets
      |> Enum.zip(@sample_raw)
      |> Enum.each(fn {opus_payload, raw} ->
        assert {:ok, ^raw} = Native.decode_packet(state, opus_payload)
      end)
    end

    test "returns descriptive errors", %{state: state} do
      packet = List.last(@sample_opus_packets)
      <<_::5, part::binary-size(8), _::bitstring>> = packet
      assert {:error, :"corrupted stream"} == Native.decode_packet(state, part)
      assert {:error, :"invalid argument"} = Native.create(321, 33)
    end
  end
end
