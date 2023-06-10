defmodule ArtemisQL.Ecto.Filters.Assoc do
  @moduledoc """
  Filter support for associations (i.e. JOIN)
  """
  import Ecto.Query
  import ArtemisQL.Types
  import ArtemisQL.Ecto.Util
  import ArtemisQL.Tokens

  @date_or_time_types [:date, :time, :datetime, :utc_datetime, :naive_datetime]

  #
  # Scalars
  #
  @scalars [:binary_id, :integer, :float, :atom, :string, :decimal, :boolean]

  def apply_type_filter(
    _type,
    query,
    {:assoc, assoc_name, field_name},
    r_null_token()
  ) do
    query
    |> where([_parent, {^assoc_name, m}], is_nil(field(m, ^field_name)))
  end

  def apply_type_filter(
    _type,
    query,
    _key,
    r_wildcard_token()
  ) do
    query
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_list_token(items: items)
  ) when type in @scalars do
    items =
      Enum.map(items, fn r_value_token(value: value) ->
        value
      end)

    query
    |> where([_parent, {^assoc_name, m}], field(m, ^field_name) in ^items)
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_value_token(value: value)
  ) when type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  def apply_type_filter(
    _type,
    query,
    {:assoc, assoc_name, field_name},
    r_cmp_token(pair: {operator, r_null_token()})
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      :gte ->
        query
        |> where([_m, {^assoc_name, m}], is_nil(field(m, ^field_name)) or not is_nil(field(m, ^field_name)))

      :lte ->
        query
        |> where([_m, {^assoc_name, m}], is_nil(field(m, ^field_name)) or not is_nil(field(m, ^field_name)))

      :gt ->
        query
        |> where([_m, {^assoc_name, m}], not is_nil(field(m, ^field_name)))

      :lt ->
        query
        |> where([_m, {^assoc_name, m}], not is_nil(field(m, ^field_name)))

      :neq ->
        query
        |> where([_m, {^assoc_name, m}], not is_nil(field(m, ^field_name)))

      :eq ->
        query
        |> where([_m, {^assoc_name, m}], is_nil(field(m, ^field_name)))

      :fuzz ->
        query
        |> where([_m, {^assoc_name, m}], is_nil(field(m, ^field_name)))

      :nfuzz ->
        query
        |> where([_m, {^assoc_name, m}], not is_nil(field(m, ^field_name)))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_cmp_token(pair: {operator, r_value_token(value: value)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^value)

      :lte ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^value)

      :gt ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) > ^value)

      :lt ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) < ^value)

      :neq ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) != ^value)

      :eq ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)

      :fuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([_m, {^assoc_name, m}], fragment("? ILIKE ?", field(m, ^field_name), ^value))

      :nfuzz ->
        value = "%#{escape_string_for_like(value)}%"

        query
        |> where([_m, {^assoc_name, m}], fragment("? NOT ILIKE ?", field(m, ^field_name), ^value))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_cmp_token(pair: {operator, r_partial_token(items: items)})
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq, :fuzz] ->
        query
        |> where([_m, {^assoc_name, m}], fragment("?::text NOT ILIKE ?", field(m, ^field_name), ^pattern))

      op when op in [:gte, :lte, :eq, :nfuzz] ->
        query
        |> where([_m, {^assoc_name, m}], fragment("?::text ILIKE ?", field(m, ^field_name), ^pattern))
    end
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_group_token(items: [r_token(kind: kind) = item])
  ) when kind in [:list, :value, :partial] do
    apply_type_filter(type, query, key, item)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_cmp_token(pair: {operator, r_group_token(items: [r_token(kind: kind) = item])})
  ) when type in @scalars and kind in [:value, :partial] do
    # rebuild the group as if, it was a list
    apply_type_filter(
      type,
      query,
      key,
      r_cmp_token(pair: {operator, r_group_token(items: [r_list_token(items: [item])])})
    )
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_cmp_token(pair: {operator, r_group_token(items: [r_list_token(items: items)])})
  ) when type in @scalars do
    # OP(a,b,c)
    case operator do
      :gte ->
        Enum.reduce(items, query, fn r_value_token(value: value), query ->
          query
          |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^value)
        end)

      :lte ->
        Enum.reduce(items, query, fn r_value_token(value: value), query ->
          query
          |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^value)
        end)

      :gt ->
        Enum.reduce(items, query, fn r_value_token(value: value), query ->
          query
          |> where([_m, {^assoc_name, m}], field(m, ^field_name) > ^value)
        end)

      :lt ->
        Enum.reduce(items, query, fn r_value_token(value: value), query ->
          query
          |> where([_m, {^assoc_name, m}], field(m, ^field_name) < ^value)
        end)

      :neq ->
        values =
          Enum.map(items, fn r_value_token(value: value) ->
            value
          end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) not in ^values)

      :eq ->
        values =
          Enum.map(items, fn r_value_token(value: value) ->
            value
          end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) in ^values)

      :fuzz ->
        Enum.reduce(items, query, fn
          r_value_token(value: value), query ->
            value = "%#{escape_string_for_like(value)}%"

            query
            |> where([_m, {^assoc_name, m}], fragment("? ILIKE ?", field(m, ^field_name), ^value))
        end)

      :nfuzz ->
        Enum.reduce(items, query, fn
          r_value_token(value: value), query ->
            value = "%#{escape_string_for_like(value)}%"

            query
            |> where([_m, {^assoc_name, m}], fragment("? NOT ILIKE ?", field(m, ^field_name), ^value))
        end)
    end
  end

  def apply_type_filter(
    :integer,
    query,
    {:assoc, assoc_name, field_name},
    r_partial_token(items: elements)
  ) do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([_m, {^assoc_name, m}], fragment("?::text ILIKE ?", field(m, ^field_name), ^pattern))
  end

  def apply_type_filter(
    :string,
    query,
    {:assoc, assoc_name, field_name},
    r_partial_token(items: elements)
  ) do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([_m, {^assoc_name, m}], fragment("? ILIKE ?", field(m, ^field_name), ^pattern))
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name_a},
    r_range_token(pair: {r_infinity_token(), r_pin_token(value: field_name_b)})
  ) when type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) <= field(m, ^field_name_b))
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_range_token(pair: {r_infinity_token(), r_value_token(value: b)})
  ) when type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^b)
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name_a},
    r_range_token(pair: {r_pin_token(value: field_name_b), r_infinity_token()})
  ) when is_atom(field_name_b) and type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) >= field(m, ^field_name_b))
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_range_token(pair: {r_value_token(value: a), r_infinity_token()})
  ) when type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^a)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_token() = start_value, r_token() = end_value})
  ) when type in @scalars do
    query = apply_type_filter(type, query, key, r_range_token(pair: {start_value, r_infinity_token()}))
    query = apply_type_filter(type, query, key, r_range_token(pair: {r_infinity_token(), end_value}))
    query
  end

  #
  # Date
  #
  def apply_type_filter(
    :date,
    query,
    {:assoc, assoc_name, field_name},
    r_value_token(value: %Date{} = value)
  ) do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  #
  # Time
  #
  def apply_type_filter(
    :time,
    query,
    {:assoc, assoc_name, field_name},
    r_value_token(value: %Time{} = value)
  ) do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  #
  # NaiveDateTime
  #
  def apply_type_filter(
    :naive_datetime,
    query,
    {:assoc, assoc_name, field_name},
    r_value_token(value: %NaiveDateTime{} = value)
  ) do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  #
  # UTC DateTime
  #
  def apply_type_filter(
    :utc_datetime,
    query,
    {:assoc, assoc_name, field_name},
    r_value_token(value: %DateTime{} = value)
  ) do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name_a},
    r_range_token(pair: {r_infinity_token(), r_pin_token(value: field_name_b)})
  ) when is_atom(field_name_b) and type in @date_or_time_types do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) <= field(m, ^field_name_b))
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_range_token(pair: {r_infinity_token(), r_token() = value})
  ) when type in @date_or_time_types do
    end_datetime = value_to_type_of(type, value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^end_datetime)
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name_a},
    r_range_token(pair: {r_pin_token(value: field_name_b), r_infinity_token()})
  ) when type in @date_or_time_types do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) >= field(m, ^field_name_b))
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_range_token(pair: {r_token() = value, r_infinity_token()})
  ) when type in @date_or_time_types do
    start_datetime = value_to_type_of(type, value, :start)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_datetime)
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, _assoc_name, _field_name} = assoc,
    r_range_token(pair: {r_token() = start_value, r_token() = end_value})
  ) when type in @date_or_time_types do
    query = apply_type_filter(type, query, assoc, {:range, {start_value, r_infinity_token()}})
    query = apply_type_filter(type, query, assoc, {:range, {r_infinity_token(), end_value}})
    query
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_token(kind: kind) = token
  ) when type in @date_or_time_types and kind in [:partial, :value] do
    start_datetime = value_to_type_of(type, token, :start)
    end_datetime = value_to_type_of(type, token, :end)
    query
    |> where([_m, {^assoc_name, m}],
      field(m, ^field_name) >= ^start_datetime and
      field(m, ^field_name) <= ^end_datetime
    )
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name_a},
    r_cmp_token(pair: {operator, r_pin_token(value: field_name_b)})
  ) when is_atom(field_name_b) and type in @date_or_time_types do
    case operator do
      :gte ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) >= field(m, ^field_name_b))

      :lte ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) <= field(m, ^field_name_b))

      :gt ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) > field(m, ^field_name_b))

      :lt ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) < field(m, ^field_name_b))

      val when val in [:neq, :nfuzz] ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) != field(m, ^field_name_b))

      val when val in [:eq, :fuzz] ->
        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name_a) == field(m, ^field_name_b))
    end
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    r_cmp_token(pair: {operator, r_token() = token})
  ) when type in @date_or_time_types do
    case operator do
      :gte ->
        value = value_to_type_of(type, token, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^value)

      :lte ->
        value = value_to_type_of(type, token, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^value)

      :gt ->
        value = value_to_type_of(type, token, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) > ^value)

      :lt ->
        value = value_to_type_of(type, token, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) < ^value)

      val when val in [:neq, :nfuzz] ->
        value = value_to_type_of(type, token, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) != ^value)

      val when val in [:eq, :fuzz] ->
        value = value_to_type_of(type, token, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
    end
  end
end
