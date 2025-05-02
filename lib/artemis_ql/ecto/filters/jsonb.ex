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
    dyn = dynamic(is_nil(^make_json_path_fragment(type, key, keys)))

    query
    |> where(^dyn)
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
    base = make_json_path_fragment(type, key, keys)
    handle_scalar_list_query(query, base, items)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_pin_token(value: field_name)
  ) when type in @scalars do
    query
    |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) == field(m, ^field_name)))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_value_token(value: value)
  ) when type in @scalars do
    query
    |> where(^dynamic(^make_json_path_fragment(type, key, keys) == ^value))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, keys},
    r_cmp_token(pair: {operator, r_null_token()})
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      op when op in [:gte, :lte, :fuzz] ->
        query
        |> where(^dynamic(
          is_nil(^make_json_path_fragment(type, key, keys)) or
          not is_nil(^make_json_path_fragment(type, key, keys))
        ))

      op when op in [:gt, :lt, :neq, :nfuzz] ->
        query
        |> where(^dynamic(not is_nil(^make_json_path_fragment(type, key, keys))))

      :eq ->
        query
        |> where(^dynamic(is_nil(^make_json_path_fragment(type, key, keys))))
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
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) >= field(m, ^field_name)))

      :lte ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) <= field(m, ^field_name)))

      :gt ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) > field(m, ^field_name)))

      :lt ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) < field(m, ^field_name)))

      :neq ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) != field(m, ^field_name)))

      :eq ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) == field(m, ^field_name)))

      :fuzz ->
        query
        |> where(^dynamic([m], fragment("? ILIKE ?", ^make_json_path_fragment(type, key, keys), field(m, ^field_name))))

      :nfuzz ->
        query
        |> where(^dynamic([m], fragment("? NOT ILIKE ?", ^make_json_path_fragment(type, key, keys), field(m, ^field_name))))
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
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) >= ^value))

      :lte ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) <= ^value))

      :gt ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) > ^value))

      :lt ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) < ^value))

      :neq ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) != ^value))

      :eq ->
        query
        |> where(^dynamic([m], ^make_json_path_fragment(type, key, keys) == ^value))

      :fuzz ->
        pattern = "%#{escape_string_for_like(to_string(value))}%"

        query
        |> where(^dynamic(
          fragment("? ILIKE ?",
            ^make_json_path_fragment(:string, key, keys),
            ^pattern
          )
        ))

      :nfuzz ->
        pattern = "%#{escape_string_for_like(to_string(value))}%"

        query
        |> where(^dynamic(
          fragment("? NOT ILIKE ?",
            ^make_json_path_fragment(:string, key, keys),
            ^pattern
          )
        ))
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
        |> where(^dynamic(
          fragment("?::text NOT ILIKE ?",
            ^make_json_path_fragment(type, key, keys),
            ^pattern
          )
        ))

      op when op in [:gte, :lte, :eq, :fuzz] ->
        query
        |> where(^dynamic(
          fragment("?::text ILIKE ?",
            ^make_json_path_fragment(type, key, keys),
            ^pattern
          )
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
    |> where(^dynamic(
      fragment("?::text ILIKE ?",
        ^make_json_path_fragment(type, key, keys),
        ^pattern
      )
    ))
  end

  def make_json_path_fragment(type, key, keys) do
    do_make_json_path_fragment(type, dynamic([m], field(m, ^key)), keys)
  end

  defp do_make_json_path_fragment(:integer, base, [a]) do
    dynamic(fragment("(?->>?)::integer", ^base, ^a))
  end

  defp do_make_json_path_fragment(:float, base, [a]) do
    dynamic(fragment("(?->>?)::float", ^base, ^a))
  end

  defp do_make_json_path_fragment(:decimal, base, [a]) do
    dynamic(fragment("(?->>?)::decimal", ^base, ^a))
  end

  defp do_make_json_path_fragment(:boolean, base, [a]) do
    dynamic(fragment("(?->>?)::boolean", ^base, ^a))
  end

  defp do_make_json_path_fragment(_type, base, [a]) do
    dynamic(fragment("?->>?", ^base, ^a))
  end

  defp do_make_json_path_fragment(type, base, [a | keys]) do
    do_make_json_path_fragment(type, dynamic(fragment("?->?", ^base, ^a)), keys)
  end
end
