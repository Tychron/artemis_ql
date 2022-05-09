defmodule ArtemisQL.Ecto.Util do
  @sql_wildcard "%"
  @sql_any_char "_"

  def escape_string_for_like(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  def partial_to_like_pattern(items) when is_list(items) do
    value =
      Enum.map(items, fn
        :wildcard ->
          @sql_wildcard

        :any_char ->
          @sql_any_char

        {:value, val} when is_integer(val) ->
          val
          |> Integer.to_string(10)

        {:value, val} when is_binary(val) ->
          val
          |> escape_string_for_like()
      end)

    IO.iodata_to_binary(value)
  end
end
