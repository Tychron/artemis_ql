defmodule ArtemisQL.Ecto.Filters.Plain do
  import Ecto.Query
  import ArtemisQL.Types
  import ArtemisQL.Tokens
  import ArtemisQL.Ecto.Util

  @date_or_time_types [:date, :time, :datetime, :utc_datetime, :naive_datetime]

  #
  # Scalars
  #
  @scalars [:binary_id, :integer, :float, :atom, :string, :decimal, :boolean]

  def apply_type_filter(_type, query, key, r_null_token()) do
    query
    |> where([m], is_nil(field(m, ^key)))
  end

  def apply_type_filter(_type, query, key, r_pin_token(value: field_name)) when is_atom(field_name) do
    query
    |> where([m], field(m, ^key) == field(m, ^field_name))
  end

  def apply_type_filter(_type, query, _key, r_wildcard_token()) do
    query
  end

  def apply_type_filter(type, query, key, r_list_token(items: items)) when type in @scalars do
    items =
      Enum.map(items, fn r_value_token(value: value) ->
        value
      end)

    query
    |> where([m], field(m, ^key) in ^items)
  end

  def apply_type_filter(type, query, key, r_value_token(value: value)) when type in @scalars do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(
    _type,
    query,
    key,
    r_cmp_token(pair: {operator, r_null_token()})
  ) do
    # normally you should only be using either NEQ or EQ in this case, the others are just stupid
    # placeholders for now
    case operator do
      :gte ->
        query
        |> where([m], is_nil(field(m, ^key)) or not is_nil(field(m, ^key)))

      :lte ->
        query
        |> where([m], is_nil(field(m, ^key)) or not is_nil(field(m, ^key)))

      :gt ->
        query
        |> where([m], not is_nil(field(m, ^key)))

      :lt ->
        query
        |> where([m], not is_nil(field(m, ^key)))

      :neq ->
        query
        |> where([m], not is_nil(field(m, ^key)))

      :eq ->
        query
        |> where([m], is_nil(field(m, ^key)))

      :fuzz ->
        query
        |> where([m], is_nil(field(m, ^key)))

      :nfuzz ->
        query
        |> where([m], not is_nil(field(m, ^key)))
    end
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_cmp_token(pair: {:fuzz, r_value_token(value: value)})
  ) when type in @scalars do
    value = "%#{escape_string_for_like(to_string(value))}%"

    query
    |> where([m], fragment("?::text ILIKE ?", field(m, ^key), ^value))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_cmp_token(pair: {:nfuzz, r_value_token(value: value)})
  ) when type in @scalars do
    value = "%#{escape_string_for_like(to_string(value))}%"

    query
    |> where([m], fragment("?::text NOT ILIKE ?", field(m, ^key), ^value))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_cmp_token(pair: {operator, r_value_token(value: value)})
  ) when type in @scalars do
    case operator do
      :gte ->
        query
        |> where([m], field(m, ^key) >= ^value)

      :lte ->
        query
        |> where([m], field(m, ^key) <= ^value)

      :gt ->
        query
        |> where([m], field(m, ^key) > ^value)

      :lt ->
        query
        |> where([m], field(m, ^key) < ^value)

      :neq ->
        query
        |> where([m], field(m, ^key) != ^value)

      :eq ->
        query
        |> where([m], field(m, ^key) == ^value)
    end
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_cmp_token(pair: {operator, r_partial_token(items: items)})
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq, :nfuzz] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?", field(m, ^key), ^pattern))

      op when op in [:gte, :lte, :eq, :fuzz] ->
        query
        |> where([m], fragment("?::text ILIKE ?", field(m, ^key), ^pattern))
    end
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_group_token(items: [{kind, _value, _meta} = item])
  ) when kind in [:list, :value, :partial] do
    apply_type_filter(type, query, key, item)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_cmp_token(pair: {operator, r_group_token(items: [{kind, _value, _meta} = item])})
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
    key,
    r_cmp_token(pair: {operator, r_group_token(items: [r_list_token(items: items)])})
  ) when type in @scalars do
    # OP(a,b,c)
    case operator do
      :gte ->
        Enum.reduce(items, query, fn r_value_token(value: value), query ->
          query
          |> where([m], field(m, ^key) >= ^value)
        end)

      :lte ->
        Enum.reduce(items, query, fn r_value_token(value: value), query ->
          query
          |> where([m], field(m, ^key) <= ^value)
        end)

      :gt ->
        Enum.reduce(items, query, fn r_value_token(value: value), query ->
          query
          |> where([m], field(m, ^key) > ^value)
        end)

      :lt ->
        Enum.reduce(items, query, fn r_value_token(value: value), query ->
          query
          |> where([m], field(m, ^key) < ^value)
        end)

      :neq ->
        values =
          Enum.map(items, fn r_value_token(value: value) ->
            value
          end)

        query
        |> where([m], field(m, ^key) not in ^values)

      :eq ->
        values =
          Enum.map(items, fn r_value_token(value: value) ->
            value
          end)

        query
        |> where([m], field(m, ^key) in ^values)

      :fuzz ->
        Enum.reduce(items, query, fn
          r_value_token(value: value), query ->
            value = "%#{escape_string_for_like(value)}%"

            query
            |> where([m], fragment("? ILIKE ?", field(m, ^key), ^value))
        end)

      :nfuzz ->
        Enum.reduce(items, query, fn
          r_value_token(value: value), query ->
            value = "%#{escape_string_for_like(value)}%"

            query
            |> where([m], fragment("? NOT ILIKE ?", field(m, ^key), ^value))
        end)
    end
  end

  def apply_type_filter(
    :integer,
    query,
    key,
    r_partial_token(items: elements)
  ) do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([m], fragment("?::text ILIKE ?", field(m, ^key), ^pattern))
  end

  def apply_type_filter(
    :string,
    query,
    key,
    r_partial_token(items: elements)
  ) do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([m], fragment("? ILIKE ?", field(m, ^key), ^pattern))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_infinity_token(), r_pin_token(value: field_name)})
  ) when type in @scalars do
    query
    |> where([m], field(m, ^key) <= field(m, ^field_name))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_infinity_token(), r_value_token(value: b)})
  ) when type in @scalars do
    query
    |> where([m], field(m, ^key) <= ^b)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_value_token(value: a), r_infinity_token()})
  ) when type in @scalars do
    query
    |> where([m], field(m, ^key) >= ^a)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_pin_token(value: field_name), r_infinity_token()})
  ) when type in @scalars do
    query
    |> where([m], field(m, ^key) >= field(m, ^field_name))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {start_value, end_value})
  ) when type in @scalars do
    query = apply_type_filter(type, query, key, r_range_token(pair: {start_value, r_infinity_token()}))
    query = apply_type_filter(type, query, key, r_range_token(pair: {r_infinity_token(), end_value}))
    query
  end

  #
  # Date, Time, DateTime, NaiveDateTime - with pinned fields
  #
  def apply_type_filter(
    :date,
    query,
    key,
    r_value_token(value: %Date{} = value)
  ) do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(
    :utc_datetime,
    query,
    key,
    r_value_token(value: %DateTime{} = value)
  ) do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(
    :naive_datetime,
    query,
    key,
    r_value_token(value: %NaiveDateTime{} = value)
  ) do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(
    :time,
    query,
    key,
    r_value_token(value: %Time{} = value)
  ) do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_infinity_token(), r_pin_token(value: field_name)})
  ) when type in @date_or_time_types do
    query
    |> where([m], field(m, ^key) <= field(m, ^field_name))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_infinity_token(), end_value})
  ) when type in @date_or_time_types do
    end_date = value_to_type_of(type, end_value, :end)
    query
    |> where([m], field(m, ^key) <= ^end_date)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_pin_token(value: field_name), r_infinity_token()})
  ) when type in @date_or_time_types do
    query
    |> where([m], field(m, ^key) >= field(m, ^field_name))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {start_value, r_infinity_token()})
  ) when type in @date_or_time_types do
    start_date = value_to_type_of(type, start_value, :start)
    query
    |> where([m], field(m, ^key) >= ^start_date)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_range_token(pair: {r_token() = start_value, r_token() = end_value})
  ) when type in @date_or_time_types do
    query = apply_type_filter(type, query, key, r_range_token(pair: {start_value, r_infinity_token()}))
    query = apply_type_filter(type, query, key, r_range_token(pair: {r_infinity_token(), end_value}))
    query
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_token(kind: kind) = value
  ) when type in @date_or_time_types and kind in [:partial, :value] do
    start_date = value_to_type_of(type, value, :start)
    end_date = value_to_type_of(type, value, :end)
    apply_type_filter(
      type,
      query,
      key,
      r_range_token(
        pair: {r_value_token(value: start_date), r_value_token(value: end_date)}
      )
    )
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_cmp_token(pair: {operator, r_pin_token(value: field_name)})
  ) when is_atom(field_name) and type in @date_or_time_types do
    case operator do
      :gte ->
        query
        |> where([m], field(m, ^key) >= field(m, ^field_name))

      :lte ->
        query
        |> where([m], field(m, ^key) <= field(m, ^field_name))

      :gt ->
        query
        |> where([m], field(m, ^key) > field(m, ^field_name))

      :lt ->
        query
        |> where([m], field(m, ^key) < field(m, ^field_name))

      val when val in [:neq, :nfuzz] ->
        query
        |> where([m], field(m, ^key) != field(m, ^field_name))

      val when val in [:eq, :fuzz] ->
        query
        |> where([m], field(m, ^key) == field(m, ^field_name))
    end
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_cmp_token(pair: {operator, r_token() = value_token})
  ) when type in @date_or_time_types do
    case operator do
      :gte ->
        date = value_to_type_of(type, value_token, :start)

        query
        |> where([m], field(m, ^key) >= ^date)

      :lte ->
        date = value_to_type_of(type, value_token, :end)

        query
        |> where([m], field(m, ^key) <= ^date)

      :gt ->
        date = value_to_type_of(type, value_token, :start)

        query
        |> where([m], field(m, ^key) > ^date)

      :lt ->
        date = value_to_type_of(type, value_token, :end)

        query
        |> where([m], field(m, ^key) < ^date)

      val when val in [:neq, :nfuzz] ->
        date = value_to_type_of(type, value_token, :start)

        query
        |> where([m], field(m, ^key) != ^date)

      val when val in [:eq, :fuzz] ->
        date = value_to_type_of(type, value_token, :start)

        query
        |> where([m], field(m, ^key) == ^date)
    end
  end
end
