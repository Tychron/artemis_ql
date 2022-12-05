defmodule ArtemisQL.Ecto.Filters.JSONB do
  import Ecto.Query
  import ArtemisQL.Ecto.Util

  #
  # Scalars
  #
  @scalars [:binary_id, :integer, :float, :atom, :string, :decimal, :boolean]

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    nil
  ) when type in @scalars do
    query
    |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^a)))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    nil
  ) when type in @scalars do
    query
    |> where([m], is_nil(fragment("?->?->>?", field(m, ^key), ^a, ^b)))
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    nil
  ) when type in @scalars do
    query
    |> where([m], is_nil(fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c)))
  end

  def apply_type_filter(_type, query, _key, :wildcard) do
    query
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    {:list, items}
  ) when type in @scalars do
    items =
      Enum.map(items, fn {:value, item} ->
        item
      end)

    query
    |> where([m], fragment("?->>?", field(m, ^key), ^a) in ^items)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    {:list, items}
  ) when type in @scalars do
    items =
      Enum.map(items, fn {:value, item} ->
        item
      end)

    query
    |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) in ^items)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    {:list, items}
  ) when type in @scalars do
    items =
      Enum.map(items, fn {:value, item} ->
        item
      end)

    query
    |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) in ^items)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    {:value, value}
  ) when type in @scalars do
    value = to_string(value)

    query
    |> where([m], fragment("?->>?", field(m, ^key), ^a) == ^value)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    {:value, value}
  ) when type in @scalars do
    value = to_string(value)

    query
    |> where([m], fragment("?->?->>?", field(m, ^key), ^a, ^b) == ^value)
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    {:value, value}
  ) when type in @scalars do
    value = to_string(value)

    query
    |> where([m], fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c) == ^value)
  end

  def apply_type_filter(
    _type,
    query,
    {:jsonb, key, [a]},
    {:cmp, {operator, nil}}
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      op when op in [:gte, :lte] ->
        query
        |> where([m], is_nil(fragment("?->>?", field(m, ^key), ^a)) or
          not is_nil(fragment("?->>?", field(m, ^key), ^a)))

      op when op in [:gt, :lt, :neq] ->
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
    {:cmp, {operator, nil}}
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      op when op in [:gte, :lte] ->
        query
        |> where([m], is_nil(fragment("?->?->>?", field(m, ^key), ^a, ^b)) or
          not is_nil(fragment("?->?->>?", field(m, ^key), ^a, ^b)))

      op when op in [:gt, :lt, :neq] ->
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
    {:cmp, {operator, nil}}
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      op when op in [:gte, :lte] ->
        query
        |> where([m], is_nil(fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c)) or
          not is_nil(fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c)))

      op when op in [:gt, :lt, :neq] ->
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
    {:cmp, {operator, {:value, value}}}
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
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b]},
    {:cmp, {operator, {:value, value}}}
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
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a, b, c]},
    {:cmp, {operator, {:value, value}}}
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
    end
  end

  def apply_type_filter(
    type,
    query,
    {:jsonb, key, [a]},
    {:cmp, {operator, {:partial, items}}}
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?",
          fragment("?->>?", field(m, ^key), ^a),
          ^pattern
        ))

      op when op in [:gte, :lte, :eq] ->
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
    {:cmp, {operator, {:partial, items}}}
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?",
          fragment("?->?->>?", field(m, ^key), ^a, ^b),
          ^pattern
        ))

      op when op in [:gte, :lte, :eq] ->
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
    {:cmp, {operator, {:partial, items}}}
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?",
          fragment("?->?->?->>?", field(m, ^key), ^a, ^b, ^c),
          ^pattern
        ))

      op when op in [:gte, :lte, :eq] ->
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
    {:partial, elements}
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
    {:partial, elements}
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
    {:partial, elements}
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
