defmodule Membrane.Opus.Parser.Delimitation do
  @moduledoc false
  # Helper module for delimiting or undelimiting packets

  @type delimitation_t :: :delimit | :undelimit | :keep

  @type handler_t ::
          (data :: binary, frame_lengths :: [non_neg_integer], header_size :: pos_integer ->
             handled :: binary)

  @spec get_handler(
          delimitation :: delimitation_t(),
          self_delimiting? :: boolean
        ) ::
          {handler :: handler_t, self_delimiting? :: boolean}
  def get_handler(delimitation, self_delimiting?) do
    cond do
      self_delimiting? && delimitation == :undelimit ->
        {fn data, frame_lengths, header_size -> undelimit(data, frame_lengths, header_size) end,
         false}

      !self_delimiting? && delimitation == :delimit ->
        {fn data, frame_lengths, header_size -> delimit(data, frame_lengths, header_size) end,
         true}

      true ->
        {fn data, _frame_lengths, _header_size -> data end, self_delimiting?}
    end
  end

  @spec delimit(data :: binary, frame_lengths :: [non_neg_integer], header_size :: pos_integer) ::
          delimited_data :: binary
  defp delimit(data, frame_lengths, header_size) do
    <<head::binary-size(header_size), body::binary>> = data
    <<head::binary, frame_lengths |> List.last() |> encode_length()::binary, body::binary>>
  end

  @spec undelimit(data :: binary, frame_lengths :: [non_neg_integer], header_size :: pos_integer) ::
          undelimited_data :: binary
  defp undelimit(data, frame_lengths, header_size) do
    last_length = frame_lengths |> List.last() |> encode_length()
    last_length_size = byte_size(last_length)
    parsed_header_size = header_size - last_length_size

    <<parsed_head::binary-size(parsed_header_size), _last_length::binary-size(last_length_size),
      body::binary>> = data

    <<parsed_head::binary, body::binary>>
  end

  @spec encode_length(length :: non_neg_integer) :: encoded_length :: binary
  defp encode_length(length) do
    if length < 252 do
      <<length::size(8)>>
    else
      <<252 + rem(length - 252, 4)::size(8), div(length - 252, 4)::size(8)>>
    end
  end
end
