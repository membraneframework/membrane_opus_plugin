defmodule Membrane.Opus.Encoder.Native.CreateTest do
  use ExUnit.Case, async: true

  alias Membrane.Opus.Encoder.Native

  test "create raises on an invalid bitrate" do
    assert is_reference(Native.create(48_000, 2, 2048, -1000, -1000))
    assert_raise ErlangError, fn -> Native.create(48_000, 2, 2048, -5, -1000) end
  end
end
