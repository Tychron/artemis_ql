defmodule ArtemisQL.Ecto.Filters.JSONB do
  import Ecto.Query
  import ArtemisQL.Ecto.Util
  import ArtemisQL.Tokens

  #
  # Scalars
  #
  @scalars [:binary_id, :integer, :float, :atom, :string, :decimal, :boolean]

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_null_token()
  ) when type in @scalars do
    query
    |> where([m], is_nil(^make_json_path_fragment(key, keys)))
  end

  def apply_type_filter(_type, query, _key, r_wildcard_token()) do
    query
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_list_token(items: items)
  ) when type in @scalars do
    base = make_json_path_fragment(key, keys)
    handle_scalar_list_query(query, base, items)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_pin_token(value: field_name)
  ) when type in @scalars do
    query
    |> where([m], ^make_json_path_fragment(key, keys) == field(m, ^field_name))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_value_token(value: value)
  ) when type in @scalars do
    value = to_string(value)

    query
    |> where([m], ^make_json_path_fragment(key, keys) == ^value)
  end

  def apply_type_filter(
    _type,
    query,
    {:jsonb, key, keys},
    r_cmp_token(pair: {operator, r_null_token()})
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      op when op in [:gte, :lte, :fuzz] ->
        query
        |> where([m], is_nil(^make_json_path_fragment(key, keys)) or
          not is_nil(^make_json_path_fragment(key, keys)))

      op when op in [:gt, :lt, :neq, :nfuzz] ->
        query
        |> where([m], not is_nil(^make_json_path_fragment(key, keys)))

      :eq ->
        query
        |> where([m], is_nil(^make_json_path_fragment(key, keys)))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_cmp_token(pair: {operator, r_pin_token(value: field_name)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) >= field(m, ^field_name))

      :lte ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) <= field(m, ^field_name))

      :gt ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) > field(m, ^field_name))

      :lt ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) < field(m, ^field_name))

      :neq ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) != field(m, ^field_name))

      :eq ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) == field(m, ^field_name))

      :fuzz ->
        query
        |> where([m], fragment("? ILIKE ?", ^make_json_path_fragment(key, keys), field(m, ^field_name)))

      :nfuzz ->
        query
        |> where([m], fragment("? NOT ILIKE ?", ^make_json_path_fragment(key, keys), field(m, ^field_name)))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_cmp_token(pair: {operator, r_value_token(value: value)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) >= ^value)

      :lte ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) <= ^value)

      :gt ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) > ^value)

      :lt ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) < ^value)

      :neq ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) != ^value)

      :eq ->
        query
        |> where([m], ^make_json_path_fragment(key, keys) == ^value)

      :fuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([m], fragment("? ILIKE ?", ^make_json_path_fragment(key, keys), ^value))

      :nfuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([m], fragment("? NOT ILIKE ?", ^make_json_path_fragment(key, keys), ^value))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_cmp_token(pair: {operator, r_partial_token(items: items)})
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq, :nfuzz] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?",
          ^make_json_path_fragment(key, keys),
          ^pattern
        ))

      op when op in [:gte, :lte, :eq, :fuzz] ->
        query
        |> where([m], fragment("?::text ILIKE ?",
          ^make_json_path_fragment(key, keys),
          ^pattern
        ))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_partial_token(items: elements)
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([m],
      fragment("?::text ILIKE ?",
        ^make_json_path_fragment(key, keys),
        ^pattern
      )
    )
  end

  defp make_json_path_fragment(key, keys) do
    do_make_json_path_fragment(dynamic([m], field(m, ^key)), keys)
  end

  defp do_make_json_path_fragment(base, [a]) do
    dynamic([_m], fragment("?->>?", ^base, ^a))
  end

  defp do_make_json_path_fragment(base, [a | keys]) do
    do_make_json_path_fragment(dynamic([_m], fragment("?->?", ^base, ^a)), keys)
  end
end
