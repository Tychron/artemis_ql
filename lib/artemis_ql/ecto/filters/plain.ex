defmodule ArtemisQL.Ecto.Filters.Plain do
  import Ecto.Query
  import ArtemisQL.Types
  import ArtemisQL.Ecto.Util

  #
  # Scalars
  #
  @scalars [:binary_id, :integer, :float, :atom, :string, :decimal, :boolean]

  def apply_type_filter(_type, query, key, nil) do
    query
    |> where([m], is_nil(field(m, ^key)))
  end

  def apply_type_filter(_type, query, _key, :wildcard) do
    query
  end

  def apply_type_filter(type, query, key, {:list, items}) when type in @scalars do
    items =
      Enum.map(items, fn {:value, item} ->
        item
      end)

    query
    |> where([m], field(m, ^key) in ^items)
  end

  def apply_type_filter(type, query, key, {:value, value}) when type in @scalars do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(_type, query, key, {:cmp, {operator, nil}}) do
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
    end
  end

  def apply_type_filter(type, query, key, {:cmp, {operator, {:value, value}}}) when type in @scalars do
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

  def apply_type_filter(type, query, key, {:cmp, {operator, {:partial, items}}}) when type in [:integer, :string] do
    pattern = partial_to_like_pattern(items)

    case operator do
      op when op in [:lt, :gt, :neq] ->
        query
        |> where([m], fragment("?::text NOT ILIKE ?", field(m, ^key), ^pattern))

      op when op in [:gte, :lte, :eq] ->
        query
        |> where([m], fragment("?::text ILIKE ?", field(m, ^key), ^pattern))
    end
  end

  def apply_type_filter(type, query, key, {:group, [{kind, _} = item]}) when kind in [:list,
                                                                                      :value,
                                                                                      :partial] do
    apply_type_filter(type, query, key, item)
  end

  def apply_type_filter(
        type, query, key,
        {:cmp, {operator, {:group, [{kind, _} = item]}}}
      ) when type in @scalars and kind in [:value, :partial] do
    # rebuild the group as if, it was a list
    apply_type_filter(type, query, key, {:cmp, {operator, {:group, [{:list, [item]}]}}})
  end

  def apply_type_filter(type, query, key,
        {:cmp, {operator, {:group, [{:list, items}]}}}) when type in @scalars do
    # OP(a,b,c)
    case operator do
      :gte ->
        Enum.reduce(items, query, fn {:value, value}, query ->
          query
          |> where([m], field(m, ^key) >= ^value)
        end)

      :lte ->
        Enum.reduce(items, query, fn {:value, value}, query ->
          query
          |> where([m], field(m, ^key) <= ^value)
        end)

      :gt ->
        Enum.reduce(items, query, fn {:value, value}, query ->
          query
          |> where([m], field(m, ^key) > ^value)
        end)

      :lt ->
        Enum.reduce(items, query, fn {:value, value}, query ->
          query
          |> where([m], field(m, ^key) < ^value)
        end)

      :neq ->
        values =
          Enum.map(items, fn {:value, item} ->
            item
          end)

        query
        |> where([m], field(m, ^key) not in ^values)

      :eq ->
        values =
          Enum.map(items, fn {:value, item} ->
            item
          end)

        query
        |> where([m], field(m, ^key) in ^values)
    end
  end

  def apply_type_filter(:integer, query, key, {:partial, elements}) do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([m], fragment("?::text ILIKE ?", field(m, ^key), ^pattern))
  end

  def apply_type_filter(:string, query, key, {:partial, elements}) do
    pattern = partial_to_like_pattern(elements)

    query
    |> where([m], fragment("? ILIKE ?", field(m, ^key), ^pattern))
  end

  def apply_type_filter(type, query, key, {:range, {:infinity, {:value, b}}}) when type in @scalars do
    query
    |> where([m], field(m, ^key) <= ^b)
  end

  def apply_type_filter(type, query, key, {:range, {{:value, a}, :infinity}}) when type in @scalars do
    query
    |> where([m], field(m, ^key) >= ^a)
  end

  def apply_type_filter(type, query, key, {:range, {{:value, a}, {:value, b}}}) when type in @scalars do
    query
    |> where([m], field(m, ^key) >= ^a and
                  field(m, ^key) <= ^b)
  end

  #
  # Date
  #
  def apply_type_filter(:date, query, key, {:value, %Date{} = value}) do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(:date, query, key, {:range, {:infinity,
                                                     end_value}}) do
    end_date = value_to_date(end_value, :end)
    query
    |> where([m], field(m, ^key) <= ^end_date)
  end

  def apply_type_filter(:date, query, key, {:range, {start_value,
                                                     :infinity}}) do
    start_date = value_to_date(start_value, :start)
    query
    |> where([m], field(m, ^key) >= ^start_date)
  end

  def apply_type_filter(:date, query, key, {:range, {start_value,
                                                     end_value}}) do
    start_date = value_to_date(start_value, :start)
    end_date = value_to_date(end_value, :end)
    query
    |> where([m], field(m, ^key) >= ^start_date and
                  field(m, ^key) <= ^end_date)
  end

  def apply_type_filter(:date, query, key, {kind, _value} = value) when kind in [:partial, :value] do
    start_date = value_to_date(value, :start)
    end_date = value_to_date(value, :end)
    apply_type_filter(:date, query, key, {:range, {{:value, start_date}, {:value, end_date}}})
  end

  def apply_type_filter(:date, query, key, {:cmp, {operator, value}}) do
    case operator do
      :gte ->
        date = value_to_date(value, :start)

        query
        |> where([m], field(m, ^key) >= ^date)

      :lte ->
        date = value_to_date(value, :end)

        query
        |> where([m], field(m, ^key) <= ^date)

      :gt ->
        date = value_to_date(value, :start)

        query
        |> where([m], field(m, ^key) > ^date)

      :lt ->
        date = value_to_date(value, :end)

        query
        |> where([m], field(m, ^key) < ^date)

      :neq ->
        date = value_to_date(value, :start)

        query
        |> where([m], field(m, ^key) != ^date)

      :eq ->
        date = value_to_date(value, :start)

        query
        |> where([m], field(m, ^key) == ^date)
    end
  end

  #
  # Time
  #
  def apply_type_filter(:time, query, key, {:value, %Time{} = value}) do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(:time, query, key, {:range, {:infinity,
                                                     end_value}}) do
    end_time = value_to_time(end_value, :end)
    query
    |> where([m], field(m, ^key) <= ^end_time)
  end

  def apply_type_filter(:time, query, key, {:range, {start_value,
                                                     :infinity}}) do
    start_time = value_to_time(start_value, :end)
    query
    |> where([m], field(m, ^key) >= ^start_time)
  end

  def apply_type_filter(:time, query, key, {:range, {start_value, end_value}}) do
    start_time = value_to_time(start_value, :start)
    end_time = value_to_time(end_value, :end)

    query
    |> where([m], field(m, ^key) >= ^start_time and
                  field(m, ^key) <= ^end_time)
  end

  def apply_type_filter(:time, query, key, {kind, _value} = value) when kind in [:partial, :value] do
    start_time = value_to_time(value, :start)
    end_time = value_to_time(value, :end)

    apply_type_filter(:time, query, key, {:range, {{:value, start_time}, {:value, end_time}}})
  end

  def apply_type_filter(:time, query, key, {:cmp, {operator, value}}) do
    case operator do
      :gte ->
        time = value_to_time(value, :start)

        query
        |> where([m], field(m, ^key) >= ^time)

      :lte ->
        time = value_to_time(value, :end)

        query
        |> where([m], field(m, ^key) <= ^time)

      :gt ->
        time = value_to_time(value, :start)

        query
        |> where([m], field(m, ^key) > ^time)

      :lt ->
        time = value_to_time(value, :end)

        query
        |> where([m], field(m, ^key) < ^time)

      :neq ->
        time = value_to_time(value, :start)

        query
        |> where([m], field(m, ^key) != ^time)

      :eq ->
        time = value_to_time(value, :start)

        query
        |> where([m], field(m, ^key) == ^time)
    end
  end

  #
  # NaiveDateTime
  #
  def apply_type_filter(:naive_datetime, query, key, {:value, %NaiveDateTime{} = value}) do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(:naive_datetime, query, key, {:range, {:infinity,
                                                               value}}) do
    end_datetime = value_to_naive_datetime(value, :end)
    query
    |> where([m], field(m, ^key) <= ^end_datetime)
  end

  def apply_type_filter(:naive_datetime, query, key, {:range, {value,
                                                               :infinity}}) do
    start_datetime = value_to_naive_datetime(value, :start)
    query
    |> where([m], field(m, ^key) >= ^start_datetime)
  end

  def apply_type_filter(:naive_datetime, query, key, {:range, {start_value,
                                                               end_value}}) do
    start_datetime = value_to_naive_datetime(start_value, :start)
    end_datetime = value_to_naive_datetime(end_value, :end)
    query
    |> where([m], field(m, ^key) >= ^start_datetime and
                  field(m, ^key) <= ^end_datetime)
  end

  def apply_type_filter(:naive_datetime, query, key, {kind, _value} = value) when kind in [:partial, :value] do
    start_datetime = value_to_naive_datetime(value, :start)
    end_datetime = value_to_naive_datetime(value, :end)
    query
    |> where([m], field(m, ^key) >= ^start_datetime and
                  field(m, ^key) <= ^end_datetime)
  end

  def apply_type_filter(:naive_datetime, query, key, {:cmp, {operator, value}}) do
    case operator do
      :gte ->
        naive_datetime = value_to_naive_datetime(value, :start)

        query
        |> where([m], field(m, ^key) >= ^naive_datetime)

      :lte ->
        naive_datetime = value_to_naive_datetime(value, :end)

        query
        |> where([m], field(m, ^key) <= ^naive_datetime)

      :gt ->
        naive_datetime = value_to_naive_datetime(value, :start)

        query
        |> where([m], field(m, ^key) > ^naive_datetime)

      :lt ->
        naive_datetime = value_to_naive_datetime(value, :end)

        query
        |> where([m], field(m, ^key) < ^naive_datetime)

      :neq ->
        naive_datetime = value_to_naive_datetime(value, :start)

        query
        |> where([m], field(m, ^key) != ^naive_datetime)

      :eq ->
        naive_datetime = value_to_naive_datetime(value, :start)

        query
        |> where([m], field(m, ^key) == ^naive_datetime)
    end
  end

  #
  # UTC DateTime
  #
  def apply_type_filter(:utc_datetime, query, key, {:value, %DateTime{} = value}) do
    query
    |> where([m], field(m, ^key) == ^value)
  end

  def apply_type_filter(:utc_datetime, query, key, {:range, {:infinity,
                                                             value}}) do
    end_datetime = value_to_utc_datetime(value, :end)
    query
    |> where([m], field(m, ^key) <= ^end_datetime)
  end

  def apply_type_filter(:utc_datetime, query, key, {:range, {value,
                                                             :infinity}}) do
    start_datetime = value_to_utc_datetime(value, :start)
    query
    |> where([m], field(m, ^key) >= ^start_datetime)
  end

  def apply_type_filter(:utc_datetime, query, key, {:range, {start_value,
                                                             end_value}}) do
    start_datetime = value_to_utc_datetime(start_value, :start)
    end_datetime = value_to_utc_datetime(end_value, :end)
    query
    |> where([m], field(m, ^key) >= ^start_datetime and
                  field(m, ^key) <= ^end_datetime)
  end

  def apply_type_filter(:utc_datetime, query, key, {kind, _value} = value) when kind in [:partial, :value] do
    start_datetime = value_to_utc_datetime(value, :start)
    end_datetime = value_to_utc_datetime(value, :end)
    query
    |> where([m], field(m, ^key) >= ^start_datetime and
                  field(m, ^key) <= ^end_datetime)
  end

  def apply_type_filter(:utc_datetime, query, key, {:cmp, {operator, value}}) do
    case operator do
      :gte ->
        utc_datetime = value_to_utc_datetime(value, :start)

        query
        |> where([m], field(m, ^key) >= ^utc_datetime)

      :lte ->
        utc_datetime = value_to_utc_datetime(value, :end)

        query
        |> where([m], field(m, ^key) <= ^utc_datetime)

      :gt ->
        utc_datetime = value_to_utc_datetime(value, :start)

        query
        |> where([m], field(m, ^key) > ^utc_datetime)

      :lt ->
        utc_datetime = value_to_utc_datetime(value, :end)

        query
        |> where([m], field(m, ^key) < ^utc_datetime)

      :neq ->
        utc_datetime = value_to_utc_datetime(value, :start)

        query
        |> where([m], field(m, ^key) != ^utc_datetime)

      :eq ->
        utc_datetime = value_to_utc_datetime(value, :start)

        query
        |> where([m], field(m, ^key) == ^utc_datetime)
    end
  end
end
