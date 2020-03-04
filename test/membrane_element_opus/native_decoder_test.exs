defmodule Membrane.Element.Opus.Decoder.Native.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Element.Opus.Decoder.Native
  alias Membrane.Element.Opus.Support.Reader

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
        assert {:ok, ^raw} = Native.decode_packet(state, opus_payload, 0, 20)
      end)
    end

    test "returns packet duration", %{state: state} do
      packet = @sample_opus_packets |> hd
      assert {:ok, _} = Native.decode_packet(state, packet, 0, 20)
      assert 20 = Native.get_last_packet_duration(state)
    end

    test "returns descriptive errors", %{state: state} do
      packet = List.last(@sample_opus_packets)
      <<_::16, part::binary-size(8), _::binary>> = packet
      assert {:error, :"corrupted stream"} == Native.decode_packet(state, part, 0, 20)
      assert {:error, :"invalid argument"} = Native.create(321, 33)
    end
  end
end
