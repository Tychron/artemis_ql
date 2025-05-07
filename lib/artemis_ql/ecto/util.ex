defmodule ArtemisQL.Ecto.Util do
  import Ecto.Query
  import ArtemisQL.Tokens

  @sql_wildcard "%"
  @sql_any_char "_"

  @spec handle_scalar_list_query(any(), Ecto.Query.t(), any(), [any()]) :: Ecto.Query.t()
  def handle_scalar_list_query(_type, query, field_fragment, items) do
    method = determine_list_method(items)

    case method do
      :in ->
        # This is the Array case, where values are just hard matched against the list
        items =
          items
          |> Enum.reduce([], fn
            r_wildcard_token(), acc ->
              acc

            r_value_token(value: value), acc ->
              [value | acc]
          end)
          |> Enum.reverse()

        where_query = dynamic(^field_fragment in ^items)

        query
        |> where(^where_query)

      :or ->
        # This is the partial or OR case, where individual items must be `or`-ed
        items_query =
          Enum.reduce(items, dynamic(false), fn
            r_value_token(value: value), head ->
              dynamic(^head or ^field_fragment == ^value)

            r_partial_token(items: items), head ->
              dynamic(^head or fragment("? ILIKE ?", ^field_fragment, ^partial_to_like_pattern(items)))
          end)

        query
        |> where([m], ^items_query)
    end
  end

  @spec handle_array_list_query(Ecto.Query.t(), any(), list()) :: Ecto.Query.t()
  def handle_array_list_query(query, field_fragment, items) do
    method = determine_list_method(items)

    case method do
      :in ->
        # This is the Array case, where values are just hard matched against the list
        items =
          items
          |> Enum.reduce([], fn
            r_wildcard_token(), acc ->
              acc

            r_value_token(value: value), acc ->
              [value | acc]
          end)
          |> Enum.reverse()

        query
        |> where(^dynamic(
          fragment(
            "EXISTS (SELECT 1 FROM jsonb_array_elements_text(?) AS elem WHERE elem = ANY(?))",
            ^field_fragment,
            ^items
          )
        ))

      :or ->
        # This is the partial or OR case, where individual items must be `or`-ed
        items_query =
          Enum.reduce(items, dynamic(false), fn
            r_value_token(value: value), head ->
              dynamic(^head or fragment("? @> ?", ^field_fragment, ^value))

            r_partial_token(items: items), head ->
              dynamic(
                ^head or
                fragment(
                  "EXISTS (SELECT 1 FROM jsonb_array_elements_text(?) AS elem WHERE elem ILIKE ?)",
                  ^field_fragment,
                  ^partial_to_like_pattern(items)
                )
              )
          end)

        query
        |> where([m], ^items_query)
    end
  end

  def determine_list_method(items) do
    Enum.reduce(items, :in, fn
      r_value_token(value: _value), method ->
        method

      r_wildcard_token(), method ->
        method

      r_partial_token(items: _items), _method ->
        :or
    end)
  end

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
