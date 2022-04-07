defmodule ArtemisQL.Ecto.Filters.JSONB do
  import Ecto.Query
  import ArtemisQL.Types

  #
  # Scalars
  #
  @scalars [:binary_id, :integer, :float, :atom, :string, :decimal, :boolean]

  @sql_wildcard "%"
  @sql_any_char "_"

  def apply_type_filter(type, query, {:jsonb, key, [subkey]}, nil) when type in @scalars do
    query
    |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^subkey)))
  end

  def apply_type_filter(_type, query, _key, :wildcard) do
    query
  end

  def apply_type_filter(type, query, {:jsonb, key, [subkey]}, {:list, items}) when type in @scalars do
    items =
      Enum.map(items, fn {:value, item} ->
        item
      end)

    query
    |> where([m], fragment("?->>?", field(m, ^key), ^subkey) in ^items)
  end

  def apply_type_filter(type, query, {:jsonb, key, [subkey]}, {:value, value}) when type in @scalars do
    value = to_string(value)

    query
    |> where([m], fragment("?->>?", field(m, ^key), ^subkey) == ^value)
  end

  def apply_type_filter(_type, query, {:jsonb, key, [subkey]}, {:cmp, {operator, nil}}) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      :gte ->
        query
        |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^subkey)) or not is_nil(fragment("?->>?", field(m, ^key), ^subkey)))

      :lte ->
        query
        |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^subkey)) or not is_nil(fragment("?->>?", field(m, ^key), ^subkey)))

      :gt ->
        query
        |> where([m], not is_nil(fragment("?->>?", field(m, ^key), ^subkey)))

      :lt ->
        query
        |> where([m], not is_nil(fragment("?->>?", field(m, ^key), ^subkey)))

      :neq ->
        query
        |> where([m], not is_nil(fragment("?->>?", field(m, ^key), ^subkey)))

      :eq ->
        query
        |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^subkey)))
    end
  end

  def apply_type_filter(type, query, {:jsonb, key, [subkey]}, {:cmp, {operator, {:value, value}}}) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^subkey) >= ^value)

      :lte ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^subkey) <= ^value)

      :gt ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^subkey) > ^value)

      :lt ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^subkey) < ^value)

      :neq ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^subkey) != ^value)

      :eq ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^subkey) == ^value)
    end
  end

  def apply_type_filter(type, query, {:jsonb, key, [subkey]}, {:cmp, {operator, {:partial, items}}}) when type in [:integer, :string] do
    value =
      Enum.map(items, fn
        :wildcard ->
          @sql_wildcard

        :any_char ->
          @sql_any_char

        {:value, val} when is_integer(val) or is_binary(val) ->
          val
          |> to_string()
      end)

    pattern = IO.iodata_to_binary(value)

    case operator do
      op when op in [:lt, :gt, :neq] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?", fragment("?->>?", field(m, ^key), ^subkey), ^pattern))

      op when op in [:gte, :lte, :eq] ->
        query
        |> where([m], fragment("?::text ILIKE ?", fragment("?->>?", field(m, ^key), ^subkey), ^pattern))
    end
  end

  def apply_type_filter(:integer, query, {:jsonb, key, [subkey]}, {:partial, elements}) do
    value =
      Enum.map(elements, fn
        :wildcard ->
          @sql_wildcard

        :any_char ->
          @sql_any_char

        {:value, num} when is_integer(num) ->
          num
          |> Integer.to_string()
      end)

    pattern = IO.iodata_to_binary(value)

    query
    |> where([m], fragment("?::text ILIKE ?", fragment("?->>?", field(m, ^key), ^subkey), ^pattern))
  end

  def apply_type_filter(:string, query, {:jsonb, key, [subkey]}, {:partial, elements}) do
    value =
      Enum.map(elements, fn
        :wildcard ->
          @sql_wildcard

        :any_char ->
          @sql_any_char

        {:value, str} when is_binary(str) ->
          escape_string_for_like(str)
      end)

    pattern = IO.iodata_to_binary(value)

    query
    |> where([m], fragment("?::text ILIKE ?", fragment("?->>?", field(m, ^key), ^subkey), ^pattern))
  end
end
