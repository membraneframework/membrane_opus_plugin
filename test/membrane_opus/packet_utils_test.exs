defmodule Membrane.Opus.PacketUtilsTest do
  use ExUnit.Case

  alias Membrane.Opus.PacketUtils

  test "Handle packet header with padding > 254" do
    header = <<3, 0::1, 1::1, 0::6, 255, 255, 5>>

    assert {:ok,
            %{
              mode: :silk,
              bandwidth: :narrow,
              frame_duration: 10_000_000,
              channels: 1,
              code: code
            }, data} = PacketUtils.skip_toc(header)

    assert {:ok, :cbr, 0, 513, <<>>} = PacketUtils.skip_code(code, data)
  end
end
