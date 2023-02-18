defmodule ArtemisQL.Ecto.Filters.Assoc do
  @moduledoc """
  Filter support for associations (i.e. JOIN)
  """
  import Ecto.Query
  import ArtemisQL.Types
  import ArtemisQL.Ecto.Util

  #
  # Scalars
  #
  @scalars [:binary_id, :integer, :float, :atom, :string, :decimal, :boolean]

  def apply_type_filter(_type, query, {:assoc, assoc_name, field_name}, nil) do
    query
    |> where([_parent, {^assoc_name, m}], is_nil(field(m, ^field_name)))
  end

  def apply_type_filter(_type, query, _key, :wildcard) do
    query
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    {:list, items}
  ) when type in @scalars do
    items =
      Enum.map(items, fn {:value, item} ->
        item
      end)

    query
    |> where([_parent, {^assoc_name, m}], field(m, ^field_name) in ^items)
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    {:value, value}
  ) when type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  def apply_type_filter(
    _type,
    query,
    {:assoc, assoc_name, field_name},
    {:cmp, {operator, nil}}
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
    end
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    {:cmp, {operator, {:value, value}}}
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
    end
  end

  def apply_type_filter(
    type,
    query,
    {:assoc, assoc_name, field_name},
    {:cmp, {operator, {:partial, items}}}
  ) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq] ->
        query
        |> where([_m, {^assoc_name, m}], fragment("?::text NOT ILIKE ?", field(m, ^field_name), ^pattern))

      op when op in [:gte, :lte, :eq] ->
        query
        |> where([_m, {^assoc_name, m}], fragment("?::text ILIKE ?", field(m, ^field_name), ^pattern))
    end
  end

  def apply_type_filter(
    type,
    query,
    key,
    {:group, [{kind, _} = item]}
  ) when kind in [:list, :value, :partial] do
    apply_type_filter(type, query, key, item)
  end

  def apply_type_filter(
    type,
    query,
    key,
    {:cmp, {operator, {:group, [{kind, _} = item]}}}
  ) when type in @scalars and kind in [:value, :partial] do
    # rebuild the group as if, it was a list
    apply_type_filter(type, query, key, {:cmp, {operator, {:group, [{:list, [item]}]}}})
  end

  def apply_type_filter(type, query, {:assoc, assoc_name, field_name},
        {:cmp, {operator, {:group, [{:list, items}]}}}) when type in @scalars do
    # OP(a,b,c)
    case operator do
      :gte ->
        Enum.reduce(items, query, fn {:value, value}, query ->
          query
          |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^value)
        end)

      :lte ->
        Enum.reduce(items, query, fn {:value, value}, query ->
          query
          |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^value)
        end)

      :gt ->
        Enum.reduce(items, query, fn {:value, value}, query ->
          query
          |> where([_m, {^assoc_name, m}], field(m, ^field_name) > ^value)
        end)

      :lt ->
        Enum.reduce(items, query, fn {:value, value}, query ->
          query
          |> where([_m, {^assoc_name, m}], field(m, ^field_name) < ^value)
        end)

      :neq ->
        values =
          Enum.map(items, fn {:value, item} ->
            item
          end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) not in ^values)

      :eq ->
        values =
          Enum.map(items, fn {:value, item} ->
            item
          end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) in ^values)
    end
  end

  def apply_type_filter(:integer, query, {:assoc, assoc_name, field_name}, {:partial, elements}) do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([_m, {^assoc_name, m}], fragment("?::text ILIKE ?", field(m, ^field_name), ^pattern))
  end

  def apply_type_filter(:string, query, {:assoc, assoc_name, field_name}, {:partial, elements}) do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([_m, {^assoc_name, m}], fragment("? ILIKE ?", field(m, ^field_name), ^pattern))
  end

  def apply_type_filter(type, query, {:assoc, assoc_name, field_name}, {:range, {:infinity, {:value, b}}}) when type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^b)
  end

  def apply_type_filter(type, query, {:assoc, assoc_name, field_name}, {:range, {{:value, a}, :infinity}}) when type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^a)
  end

  def apply_type_filter(type, query, {:assoc, assoc_name, field_name}, {:range, {{:value, a}, {:value, b}}}) when type in @scalars do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^a and
                  field(m, ^field_name) <= ^b)
  end

  #
  # Date
  #
  def apply_type_filter(
    :date,
    query,
    {:assoc, assoc_name, field_name},
    {:value, %Date{} = value}
  ) do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  def apply_type_filter(
    :date,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {:infinity, end_value}}
  ) do
    end_date = value_to_date(end_value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^end_date)
  end

  def apply_type_filter(
    :date,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {start_value, :infinity}}
  ) do
    start_date = value_to_date(start_value, :start)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_date)
  end

  def apply_type_filter(
    :date,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {start_value, end_value}}
  ) do
    start_date = value_to_date(start_value, :start)
    end_date = value_to_date(end_value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_date and
                  field(m, ^field_name) <= ^end_date)
  end

  def apply_type_filter(
    :date,
    query,
    key,
    {kind, _value} = value
  ) when kind in [:partial, :value] do
    start_date = value_to_date(value, :start)
    end_date = value_to_date(value, :end)
    apply_type_filter(:date, query, key, {:range, {{:value, start_date}, {:value, end_date}}})
  end

  def apply_type_filter(
    :date,
    query,
    {:assoc, assoc_name, field_name},
    {:cmp, {operator, value}}
  ) do
    case operator do
      :gte ->
        date = value_to_date(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^date)

      :lte ->
        date = value_to_date(value, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^date)

      :gt ->
        date = value_to_date(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) > ^date)

      :lt ->
        date = value_to_date(value, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) < ^date)

      :neq ->
        date = value_to_date(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) != ^date)

      :eq ->
        date = value_to_date(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^date)
    end
  end

  #
  # Time
  #
  def apply_type_filter(
    :time,
    query,
    {:assoc, assoc_name, field_name},
    {:value, %Time{} = value}
  ) do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  def apply_type_filter(
    :time,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {:infinity, end_value}}
  ) do
    end_time = value_to_time(end_value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^end_time)
  end

  def apply_type_filter(
    :time,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {start_value, :infinity}}
  ) do
    start_time = value_to_time(start_value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_time)
  end

  def apply_type_filter(
    :time,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {start_value, end_value}}
  ) do
    start_time = value_to_time(start_value, :start)
    end_time = value_to_time(end_value, :end)

    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_time and
                  field(m, ^field_name) <= ^end_time)
  end

  def apply_type_filter(
    :time,
    query,
    key,
    {kind, _value} = value
  ) when kind in [:partial, :value] do
    start_time = value_to_time(value, :start)
    end_time = value_to_time(value, :end)

    apply_type_filter(:time, query, key, {:range, {{:value, start_time}, {:value, end_time}}})
  end

  def apply_type_filter(
    :time,
    query,
    {:assoc, assoc_name, field_name},
    {:cmp, {operator, value}}
  ) do
    case operator do
      :gte ->
        time = value_to_time(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^time)

      :lte ->
        time = value_to_time(value, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^time)

      :gt ->
        time = value_to_time(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) > ^time)

      :lt ->
        time = value_to_time(value, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) < ^time)

      :neq ->
        time = value_to_time(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) != ^time)

      :eq ->
        time = value_to_time(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^time)
    end
  end

  #
  # NaiveDateTime
  #
  def apply_type_filter(
    :naive_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:value, %NaiveDateTime{} = value}
  ) do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  def apply_type_filter(
    :naive_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {:infinity, value}}
  ) do
    end_datetime = value_to_naive_datetime(value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^end_datetime)
  end

  def apply_type_filter(
    :naive_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {value, :infinity}}
  ) do
    start_datetime = value_to_naive_datetime(value, :start)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_datetime)
  end

  def apply_type_filter(
    :naive_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {start_value, end_value}}
  ) do
    start_datetime = value_to_naive_datetime(start_value, :start)
    end_datetime = value_to_naive_datetime(end_value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_datetime and
                  field(m, ^field_name) <= ^end_datetime)
  end

  def apply_type_filter(
    :naive_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {kind, _value} = value
  ) when kind in [:partial, :value] do
    start_datetime = value_to_naive_datetime(value, :start)
    end_datetime = value_to_naive_datetime(value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_datetime and
                  field(m, ^field_name) <= ^end_datetime)
  end

  def apply_type_filter(
    :naive_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:cmp, {operator, value}}
  ) do
    case operator do
      :gte ->
        naive_datetime = value_to_naive_datetime(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^naive_datetime)

      :lte ->
        naive_datetime = value_to_naive_datetime(value, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^naive_datetime)

      :gt ->
        naive_datetime = value_to_naive_datetime(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) > ^naive_datetime)

      :lt ->
        naive_datetime = value_to_naive_datetime(value, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) < ^naive_datetime)

      :neq ->
        naive_datetime = value_to_naive_datetime(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) != ^naive_datetime)

      :eq ->
        naive_datetime = value_to_naive_datetime(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^naive_datetime)
    end
  end

  #
  # UTC DateTime
  #
  def apply_type_filter(
    :utc_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:value, %DateTime{} = value}
  ) do
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^value)
  end

  def apply_type_filter(
    :utc_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {:infinity, value}}
  ) do
    end_datetime = value_to_utc_datetime(value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^end_datetime)
  end

  def apply_type_filter(
    :utc_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {value, :infinity}}
  ) do
    start_datetime = value_to_utc_datetime(value, :start)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_datetime)
  end

  def apply_type_filter(
    :utc_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:range, {start_value, end_value}}
  ) do
    start_datetime = value_to_utc_datetime(start_value, :start)
    end_datetime = value_to_utc_datetime(end_value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_datetime and
                  field(m, ^field_name) <= ^end_datetime)
  end

  def apply_type_filter(
    :utc_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {kind, _value} = value
  ) when kind in [:partial, :value] do
    start_datetime = value_to_utc_datetime(value, :start)
    end_datetime = value_to_utc_datetime(value, :end)
    query
    |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^start_datetime and
                  field(m, ^field_name) <= ^end_datetime)
  end

  def apply_type_filter(
    :utc_datetime,
    query,
    {:assoc, assoc_name, field_name},
    {:cmp, {operator, value}}
  ) do
    case operator do
      :gte ->
        utc_datetime = value_to_utc_datetime(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) >= ^utc_datetime)

      :lte ->
        utc_datetime = value_to_utc_datetime(value, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) <= ^utc_datetime)

      :gt ->
        utc_datetime = value_to_utc_datetime(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) > ^utc_datetime)

      :lt ->
        utc_datetime = value_to_utc_datetime(value, :end)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) < ^utc_datetime)

      :neq ->
        utc_datetime = value_to_utc_datetime(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) != ^utc_datetime)

      :eq ->
        utc_datetime = value_to_utc_datetime(value, :start)

        query
        |> where([_m, {^assoc_name, m}], field(m, ^field_name) == ^utc_datetime)
    end
  end
end
