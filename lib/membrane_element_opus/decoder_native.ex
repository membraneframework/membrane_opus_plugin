defmodule Membrane.Element.Opus.DecoderNative do
  @moduledoc """
  This module is an interface to native libopus-based Opus decoder.
  """


  @on_load :load_nifs

  @doc false
  def load_nifs do
    :ok = :erlang.load_nif('./membrane_element_opus_decoder', 0)
  end


  @doc """
  Creates Opus decoder.

  Expects 2 arguments:

  - sample rate (integer, one of 8000, 12000, 16000, 24000, or 48000)
  - channels (integer, 1 or 2)

  On success, returns `{:ok, resource}`.

  On bad arguments passed, returns `{:error, {:args, field, description}}`.

  On decoder initialization error, returns `{:error, {:internal, reason}}`.
  """
  @spec create(non_neg_integer, non_neg_integer) ::
  {:ok, any} |
  {:error, {:args, atom, String.t}} |
  {:error, {:internal, atom}}
  def create(_sample_rate, _channels), do: raise "NIF fail"

end
