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
    {:jsonb, key, [a]},
    r_null_token()
  ) when type in @scalars do
    query
    |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^a)))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    r_null_token()
  ) when type in @scalars do
    query
    |> where([m], is_nil(fragment("?->?->>?", field(m, ^key), ^a, ^b)))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    r_null_token()
  ) when type in @scalars do
    query
    |> where([m], is_nil(fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c)))
  end

  def apply_type_filter(_type, query, _key, r_wildcard_token()) do
    query
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    r_list_token(items: items)
  ) when type in @scalars do
    items =
      Enum.map(items, fn r_value_token(value: value) ->
        value
      end)

    query
    |> where([m], fragment("?->>?", field(m, ^key), ^a) in ^items)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    r_list_token(items: items)
  ) when type in @scalars do
    items =
      Enum.map(items, fn r_value_token(value: value) ->
        value
      end)

    query
    |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) in ^items)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    r_list_token(items: items)
  ) when type in @scalars do
    items =
      Enum.map(items, fn r_value_token(value: value) ->
        value
      end)

    query
    |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) in ^items)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    r_pin_token(value: field_name)
  ) when type in @scalars do
    query
    |> where([m], fragment("?->>?", field(m, ^key), ^a) == field(m, ^field_name))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    r_pin_token(value: field_name)
  ) when type in @scalars do
    query
    |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) == field(m, ^field_name))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    r_pin_token(value: field_name)
  ) when type in @scalars do
    query
    |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) == field(m, ^field_name))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    r_value_token(value: value)
  ) when type in @scalars do
    value = to_string(value)

    query
    |> where([m], fragment("?->>?", field(m, ^key), ^a) == ^value)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    r_value_token(value: value)
  ) when type in @scalars do
    value = to_string(value)

    query
    |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) == ^value)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    r_value_token(value: value)
  ) when type in @scalars do
    value = to_string(value)

    query
    |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) == ^value)
  end

  def apply_type_filter(
    _type,
    query,
    {:jsonb, key, [a]},
    r_cmp_token(pair: {operator, r_null_token()})
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      op when op in [:gte, :lte, :fuzz] ->
        query
        |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^a)) or
          not is_nil(fragment("?->>?", field(m, ^key), ^a)))

      op when op in [:gt, :lt, :neq, :nfuzz] ->
        query
        |> where([m], not is_nil(fragment("?->>?", field(m, ^key), ^a)))

      :eq ->
        query
        |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^a)))
    end
  end

  def apply_type_filter(
    _type,
    query,
    {:jsonb, key, [a, b]},
    r_cmp_token(pair: {operator, r_null_token()})
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      op when op in [:gte, :lte, :fuzz] ->
        query
        |> where([m], is_nil(fragment("?->?->>?", field(m, ^key), ^a, ^b)) or
          not is_nil(fragment("?->?->>?", field(m, ^key), ^a, ^b)))

      op when op in [:gt, :lt, :neq, :nfuzz] ->
        query
        |> where([m], not is_nil(fragment("?->?->>?", field(m, ^key), ^a, ^b)))

      :eq ->
        query
        |> where([m], is_nil(fragment("?->?->>?", field(m, ^key), ^a, ^b)))
    end
  end

  def apply_type_filter(
    _type,
    query,
    {:jsonb, key, [a, b, c]},
    r_cmp_token(pair: {operator, r_null_token()})
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      op when op in [:gte, :lte, :fuzz] ->
        query
        |> where([m], is_nil(fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c)) or
          not is_nil(fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c)))

      op when op in [:gt, :lt, :neq, :nfuzz] ->
        query
        |> where([m], not is_nil(fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c)))

      :eq ->
        query
        |> where([m], is_nil(fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c)))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    r_cmp_token(pair: {operator, r_pin_token(value: field_name)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) >= field(m, ^field_name))

      :lte ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) <= field(m, ^field_name))

      :gt ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) > field(m, ^field_name))

      :lt ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) < field(m, ^field_name))

      :neq ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) != field(m, ^field_name))

      :eq ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) == field(m, ^field_name))

      :fuzz ->
        query
        |> where([m], fragment("? ILIKE ?", fragment("?->>?", field(m, ^key), ^a), field(m, ^field_name)))

      :nfuzz ->
        query
        |> where([m], fragment("? NOT ILIKE ?", fragment("?->>?", field(m, ^key), ^a), field(m, ^field_name)))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    r_cmp_token(pair: {operator, r_pin_token(value: field_name)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) >= field(m, ^field_name))

      :lte ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) <= field(m, ^field_name))

      :gt ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) > field(m, ^field_name))

      :lt ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) < field(m, ^field_name))

      :neq ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) != field(m, ^field_name))

      :eq ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) == field(m, ^field_name))

      :fuzz ->
        query
        |> where([m], fragment("? ILIKE ?", fragment("?->?->>?", field(m, ^key), ^a, ^b), field(m, ^field_name)))

      :nfuzz ->
        query
        |> where([m], fragment("? NOT ILIKE ?", fragment("?->?->>?", field(m, ^key), ^a, ^b), field(m, ^field_name)))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    r_cmp_token(pair: {operator, r_pin_token(value: field_name)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) >= field(m, ^field_name))

      :lte ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) <= field(m, ^field_name))

      :gt ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) > field(m, ^field_name))

      :lt ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) < field(m, ^field_name))

      :neq ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) != field(m, ^field_name))

      :eq ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) == field(m, ^field_name))

      :fuzz ->
        query
        |> where([m], fragment("? ILIKE ?", fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c), field(m, ^field_name)))

      :nfuzz ->
        query
        |> where([m], fragment("? NOT ILIKE ?", fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c), field(m, ^field_name)))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    r_cmp_token(pair: {operator, r_value_token(value: value)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) >= ^value)

      :lte ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) <= ^value)

      :gt ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) > ^value)

      :lt ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) < ^value)

      :neq ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) != ^value)

      :eq ->
        query
        |> where([m], fragment("?->>?", field(m, ^key), ^a) == ^value)

      :fuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([m], fragment("? ILIKE ?", fragment("?->>?", field(m, ^key), ^a), ^value))

      :nfuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([m], fragment("? NOT ILIKE ?", fragment("?->>?", field(m, ^key), ^a), ^value))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    r_cmp_token(pair: {operator, r_value_token(value: value)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) >= ^value)

      :lte ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) <= ^value)

      :gt ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) > ^value)

      :lt ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) < ^value)

      :neq ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) != ^value)

      :eq ->
        query
        |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) == ^value)

      :fuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([m], fragment("? ILIKE ?", fragment("?->?->>?", field(m, ^key), ^a, ^b), ^value))

      :nfuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([m], fragment("? NOT ILIKE ?", fragment("?->?->>?", field(m, ^key), ^a, ^b), ^value))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    r_cmp_token(pair: {operator, r_value_token(value: value)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) >= ^value)

      :lte ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) <= ^value)

      :gt ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) > ^value)

      :lt ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) < ^value)

      :neq ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) != ^value)

      :eq ->
        query
        |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) == ^value)

      :fuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([m], fragment("? ILIKE ?", fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c), ^value))

      :nfuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([m], fragment("? NOT ILIKE ?", fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c), ^value))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    r_cmp_token(pair: {operator, r_partial_token(items: items)})
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq, :nfuzz] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?",
          fragment("?->>?", field(m, ^key), ^a),
          ^pattern
        ))

      op when op in [:gte, :lte, :eq, :fuzz] ->
        query
        |> where([m], fragment("?::text ILIKE ?",
          fragment("?->>?", field(m, ^key), ^a),
          ^pattern
        ))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    r_cmp_token(pair: {operator, r_partial_token(items: items)})
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq, :nfuzz] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?",
          fragment("?->?->>?", field(m, ^key), ^a, ^b),
          ^pattern
        ))

      op when op in [:gte, :lte, :eq, :fuzz] ->
        query
        |> where([m], fragment("?::text ILIKE ?",
          fragment("?->?->>?", field(m, ^key), ^a, ^b),
          ^pattern
        ))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    r_cmp_token(pair: {operator, r_partial_token(items: items)})
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq, :nfuzz] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?",
          fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c),
          ^pattern
        ))

      op when op in [:gte, :lte, :eq, :fuzz] ->
        query
        |> where([m], fragment("?::text ILIKE ?",
          fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c),
          ^pattern
        ))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    r_partial_token(items: elements)
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([m],
      fragment("?::text ILIKE ?",
        fragment("?->>?", field(m, ^key), ^a),
        ^pattern
      )
    )
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    r_partial_token(items: elements)
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([m],
      fragment("?::text ILIKE ?",
        fragment("?->?->>?", field(m, ^key), ^a, ^b),
        ^pattern
      )
    )
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    r_partial_token(items: elements)
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([m],
      fragment("?::text ILIKE ?",
        fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c),
        ^pattern
      )
    )
  end
end
