defmodule ArtemisQL.Ecto.Util do
  import ArtemisQL.Tokens

  @sql_wildcard "%"
  @sql_any_char "_"

  @spec escape_string_for_like(String.t()) :: String.t()
  def escape_string_for_like(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  @spec partial_to_like_pattern([ArtemisQL.Tokens.token()]) :: String.t()
  def partial_to_like_pattern(items) when is_list(items) do
    value =
      Enum.map(items, fn
        r_wildcard_token() ->
          @sql_wildcard

        r_any_char_token() ->
          @sql_any_char

        r_value_token(value: val) when is_integer(val) ->
          val
          |> Integer.to_string(10)

        r_value_token(value: val) when is_binary(val) ->
          val
          |> escape_string_for_like()
      end)

    IO.iodata_to_binary(value)
  end
end
