defmodule ArtemisQL.Types do
  defmodule ValueTransformError do
    defexception [message: nil, types: [], caused_by: nil]

    @impl true
    def message(%{caused_by: nil} = exception) do
      types = Enum.join(exception.types, ", ")
      "a error occured while transforming the value (tried types: #{types})"
    end

    @impl true
    def message(%{caused_by: caused_by} = exception) do
      IO.iodata_to_binary [message(%{exception | caused_by: nil}), "\n", Exception.format(:error, caused_by)]
    end
  end

  alias ArtemisQL.SearchMap

  @type partial_time ::
    {:partial_time, {hour::integer, minute::integer}}
    | {:partial_time, {hour::integer}}

  @doc """
  Attempts to whitelist the given key against the search_map, if the key is not in the map
  then :missing is returned, if the key is in the map but is being actively rejected, then
  :skip is returned instead.

  Otherwise the function returns the new atomized key as {:ok, atom}.
  """
  @spec whitelist_key(String.t(), ArtemisQL.SearchMap.t()) :: :missing | :skip | {:ok, atom()}
  def whitelist_key(key, %SearchMap{} = search_map) when is_binary(key) do
    case search_map.key_whitelist[key] do
      nil ->
        :missing

      false ->
        :skip

      true ->
        {:ok, String.to_existing_atom(key)}

      key when is_atom(key) ->
        {:ok, key}
    end
  end

  def whitelist_key(
    key,
    search_map
  ) when is_binary(key) and is_atom(search_map) and not is_boolean(search_map) do
    case apply(search_map, :key_whitelist, [key]) do
      nil ->
        :missing

      false ->
        :skip

      true ->
        {:ok, String.to_existing_atom(key)}

      key when is_atom(key) ->
        {:ok, key}
    end
  end

  def transform_pair(key, value, %SearchMap{} = search_map) when is_atom(key) do
    handle_pair_transform(search_map.pair_transform[key], key, value)
  end

  def transform_pair(
    key,
    value,
    search_map
  ) when is_atom(key) and is_atom(search_map) and not is_boolean(search_map) do
    case apply(search_map, :pair_transform, [key, value]) do
      {:ok, _key, _value} = res ->
        res

      other ->
        handle_pair_transform(other, key, value)
    end
  end

  def handle_pair_transform(type, key, {:group, [item]}) do
    case handle_pair_transform(type, key, item) do
      {:ok, key, value} ->
        {:ok, key, {:group, [value]}}

      {:abort, reason} ->
        {:abort, reason}
    end
  end

  def handle_pair_transform(type, key, {:list, items}) do
    {key, items} =
      Enum.reduce(items, {key, []}, fn value, {key, acc} ->
        case handle_pair_transform(type, key, value) do
          {:ok, key, value} ->
            {key, [value | acc]}

          {:abort, reason} ->
            throw {:abort, reason}
        end
      end)

    {:ok, key, {:list, Enum.reverse(items)}}
  end

  def handle_pair_transform(type, key, {:cmp, {operator, value}}) do
    case handle_pair_transform(type, key, value) do
      {:ok, key, value} ->
        {:ok, key, {:cmp, {operator, value}}}

      {:abort, reason} ->
        {:abort, reason}
    end
  end

  def handle_pair_transform(nil, key, value) do
    {:ok, key, value}
  end

  def handle_pair_transform({:type, module}, key, value) do
    handle_pair_transform({:type, module, %{}}, key, value)
  end

  def handle_pair_transform({:type, module, params}, key, value) do
    handle_type_module_transform(module, params, key, value)
  end

  def handle_pair_transform({:apply, module, function_name, args}, key, value) do
    :erlang.apply(module, function_name, [key, value | args])
  end

  def handle_pair_transform(function, key, value) when is_function(function) do
    function.(key, value)
  end

  def handle_type_module_transform(:binary_id, _params, key, value) do
    {:ok, key, apply_to_value(value, &to_string/1)}
  end

  def handle_type_module_transform(:boolean, _params, key, value) do
    {:ok, key, apply_to_value(value, &to_boolean/1)}
  end

  def handle_type_module_transform(:integer, _params, key, value) do
    {:ok, key, apply_to_value(value, &String.to_integer/1)}
  end

  def handle_type_module_transform(:float, _params, key, value) do
    {:ok, key, apply_to_value(value, &String.to_float/1)}
  end

  def handle_type_module_transform(:decimal, _params, key, value) do
    {:ok, key, apply_to_value(value, &Decimal.new/1)}
  end

  def handle_type_module_transform(:atom, _params, key, value) do
    {:ok, key, apply_to_value(value, &String.to_existing_atom/1)}
  end

  def handle_type_module_transform(:string, _params, key, value) do
    {:ok, key, apply_to_value(value, &normalize_value/1)}
  end

  def handle_type_module_transform(:date, _params, key, value) do
    {:ok, key, apply_to_value(value, &parse_date/1)}
  end

  def handle_type_module_transform(:time, _params, key, value) do
    {:ok, key, apply_to_value(value, &parse_time/1)}
  end

  def handle_type_module_transform(:naive_datetime, _params, key, value) do
    {:ok, key, apply_to_value(value, &parse_naive_datetime/1)}
  end

  def handle_type_module_transform(:utc_datetime, _params, key, value) do
    {:ok, key, apply_to_value(value, &parse_datetime/1)}
  end

  def apply_to_value(:infinity, _callback) do
    :infinity
  end

  def apply_to_value(:wildcard, _callback) do
    :wildcard
  end

  def apply_to_value(:NULL, _callback) do
    nil
  end

  def apply_to_value({:cmp, {operator, value}}, callback) do
    {:cmp, {operator, apply_to_value(value, callback)}}
  end

  def apply_to_value({kind, value}, callback) when kind in [:word, :quote] do
    value = callback.(value)
    {:value, value}
  end

  def apply_to_value({:partial, elements}, callback) do
    {:partial, Enum.map(elements, fn
      :wildcard ->
        :wildcard

      :any_char ->
        :any_char

      element ->
        apply_to_value(element, callback)
    end)}
  end

  def apply_to_value({:range, {a, b}}, callback) do
    {:range, {apply_to_value(a, callback), apply_to_value(b, callback)}}
  end

  def parse_date(<<"@",_::binary>> = str) do
    str
    |> parse_functional_time()
    |> DateTime.to_date()
  end

  def parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} ->
        date

      {:error, _} ->
        case Regex.scan(~r/\A(\d+)-(\d+)\z/, str) do
          [[_, year, month]] ->
            {:partial_date, {String.to_integer(year), String.to_integer(month)}}

          [] ->
            case Regex.scan(~r/\A(\d+)\z/, str) do
              [[_, year]] ->
                {:partial_date, {String.to_integer(year)}}

              [] ->
                raise %ValueTransformError{types: [:date]}
            end
        end
    end
  end

  @spec parse_time(String.t()) :: Time.t() | partial_time()
  def parse_time(<<"@",_::binary>> = str) do
    str
    |> parse_functional_time()
    |> DateTime.to_time()
  end

  def parse_time(str) when is_binary(str) do
    case Time.from_iso8601(str) do
      {:ok, time} ->
        time

      {:error, _} ->
        case Regex.scan(~r/\A(\d+):(\d+)\z/, str) do
          [[_, hour, month]] ->
            {:partial_time, {String.to_integer(hour), String.to_integer(month)}}

          [] ->
            case Regex.scan(~r/\A(\d+)\z/, str) do
              [[_, hour]] ->
                {:partial_time, {String.to_integer(hour)}}

              [] ->
                raise %ValueTransformError{types: [:time]}
            end
        end
    end
  end

  @spec parse_naive_datetime(String.t()) :: NaiveDateTime.t() | Date.t()
  def parse_naive_datetime(<<"@",_::binary>> = str) do
    str
    |> parse_functional_time()
    |> DateTime.to_naive()
  end

  def parse_naive_datetime(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, naive_datetime} ->
        naive_datetime

      {:error, _} ->
        case str do
          <<
            year::binary-size(4), "-",
            month::binary-size(2), "-",
            day::binary-size(2), "T",
            rest::binary
          >> ->
            {:partial_naive_datetime, parse_date("#{year}-#{month}-#{day}"), parse_time(rest)}

          _ ->
            case Regex.scan(~r/\A(\d+)(:\d+){1,2}/, str) do
              [_] ->
                time = parse_time(str)

                {:partial_naive_datetime, Date.utc_today(), time}

              [] ->
                parse_date(str)
            end
        end
    end
  rescue ex in ValueTransformError ->
    reraise %ValueTransformError{types: [:naive_datetime | ex.types]}, __STACKTRACE__
  end

  def parse_datetime(<<"@",_::binary>> = str) do
    str
    |> parse_functional_time()
    |> DateTime.to_date()
  end

  def parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, datetime, _} ->
        datetime

      {:error, _} ->
        case NaiveDateTime.from_iso8601(str) do
          {:ok, datetime} ->
            datetime

          {:error, _} ->
            case str do
              <<
                year::binary-size(4), "-",
                month::binary-size(2), "-",
                day::binary-size(2), "T",
                rest::binary
              >> ->
                {:partial_datetime, parse_date("#{year}-#{month}-#{day}"), parse_time(rest)}

              _ ->
                case Regex.scan(~r/\A(\d+)(:\d+){1,2}/, str) do
                  [_] ->
                    time = parse_time(str)

                    {:partial_datetime, Date.utc_today(), time}

                  [] ->
                    parse_date(str)
                end
            end
        end
    end
  rescue ex in ValueTransformError ->
    reraise %ValueTransformError{types: [:datetime | ex.types]}, __STACKTRACE__
  end

  @doc """
  """
  @spec parse_functional_time(String.t()) :: DateTime.t()
  def parse_functional_time(<<"@", rest::binary>>) do
    duration = %{
      seconds: 0,
      minutes: 0,
      hours: 0,
      days: 0,
      weeks: 0,
      months: 0,
      years: 0
    }

    {duration, anchor} =
      rest
      |> String.downcase()
      |> String.split("-")
      |> do_parse_functional_time({duration, nil})

    case anchor do
      nil ->
        raise %ValueTransformError{types: [:functional_time]}

      {:from, %DateTime{} = datetime} ->
        Timex.shift(datetime, [
          seconds: duration[:seconds],
          minutes: duration[:minutes],
          hours: duration[:hours],
          days: duration[:days] + duration[:weeks] * 7,
          months: duration[:months],
          years: duration[:years],
        ])

      {:to, %DateTime{} = datetime} ->
        Timex.shift(datetime, [
          seconds: -duration[:seconds],
          minutes: -duration[:minutes],
          hours: -duration[:hours],
          days: -(duration[:days] + duration[:weeks] * 7),
          months: -duration[:months],
          years: -duration[:years],
        ])

      %DateTime{} = datetime ->
        datetime
    end
  end

  defp do_parse_functional_time([], {_duration, _anchor} = pair) do
    pair
  end

  defp do_parse_functional_time(["from" | rest], {duration, _anchor}) do
    do_parse_functional_time(rest, {duration, {:from, nil}})
  end

  defp do_parse_functional_time(["to" | rest], {duration, _anchor}) do
    do_parse_functional_time(rest, {duration, {:to, nil}})
  end

  defp do_parse_functional_time([word, anchor_name], {duration, anchor}) when word in ["next"] do
    point =
      case anchor_name do
        "day" ->
          Timex.shift(DateTime.utc_now(), days: 1)

        "week" ->
          Timex.shift(DateTime.utc_now(), days: 7)

        "month" ->
          Timex.shift(DateTime.utc_now(), months: 1)

        "year" ->
          Timex.shift(DateTime.utc_now(), years: 1)
      end

    {duration, replace_anchor(anchor, point)}
  end

  defp do_parse_functional_time([word, anchor_name], {duration, anchor}) when word in ["last", "prev", "previous"] do
    point =
      case anchor_name do
        "day" ->
          Timex.shift(DateTime.utc_now(), days: -1)

        "week" ->
          Timex.shift(DateTime.utc_now(), days: -7)

        "month" ->
          Timex.shift(DateTime.utc_now(), months: -1)

        "year" ->
          Timex.shift(DateTime.utc_now(), years: -1)
      end

    {duration, replace_anchor(anchor, point)}
  end

  defp do_parse_functional_time([anchor_name], {duration, anchor}) do
    point =
      case anchor_name do
        "today" ->
          Timex.beginning_of_day(DateTime.utc_now())

        "now" ->
          DateTime.utc_now()

        "yesterday" ->
          Timex.shift(DateTime.utc_now(), days: -1)

        "tomorrow" ->
          Timex.shift(DateTime.utc_now(), days: 1)
      end

    {duration, replace_anchor(anchor, point)}
  end

  defp do_parse_functional_time(["and" | rest], acc) do
    do_parse_functional_time(rest, acc)
  end

  rows = [
    {:second, :seconds},
    {:minute, :minutes},
    {:hour, :hours},
    {:day, :days},
    {:week, :weeks},
    {:month, :months},
    {:year, :years}
  ]

  for {singular, unit} <- rows do
    defp do_parse_functional_time([amount, unquote(to_string(unit)) | rest], {duration, anchor}) do
      duration = %{duration | unquote(unit) => duration.unquote(unit) + String.to_integer(amount, 10)}
      do_parse_functional_time(rest, {duration, anchor})
    end

    defp do_parse_functional_time([amount, unquote(to_string(singular)) | rest], {duration, anchor}) do
      duration = %{duration | unquote(unit) => duration.unquote(unit) + String.to_integer(amount, 10)}
      do_parse_functional_time(rest, {duration, anchor})
    end
  end

  defp replace_anchor({direction, _}, value) do
    {direction, value}
  end

  defp replace_anchor(nil, value) do
    value
  end

  def normalize_value(value) do
    value
  end

  def to_boolean(value) do
    case String.downcase(value) do
      v when v in ~w[yes y 1 true t on] ->
        true

      v when v in ~w[no n 0 false f off] ->
        false
    end
  end

  #
  # Casts
  #
  def value_to_date({:value, %Date{} = date}, _) do
    date
  end

  def value_to_date({:value, {:partial_date, {year, month}}}, :start) do
    %Date{year: year, month: month, day: 1}
  end

  def value_to_date({:value, {:partial_date, {year, month}}}, :end) do
    Timex.end_of_month(%Date{year: year, month: month, day: 1})
  end

  def value_to_date({:value, {:partial_date, {year}}}, :start) do
    Timex.beginning_of_year(year)
  end

  def value_to_date({:value, {:partial_date, {year}}}, :end) do
    Timex.end_of_year(year)
  end

  def value_to_time({:value, %Time{} = time}, _) do
    time
  end

  def value_to_time({:value, {:partial_time, {hour, minute}}}, :start) do
    %Time{hour: hour, minute: minute, second: 0}
  end

  def value_to_time({:value, {:partial_time, {hour, minute}}}, :end) do
    %Time{hour: hour, minute: minute, second: 59}
  end

  def value_to_time({:value, {:partial_time, {hour}}}, :start) do
    %Time{hour: hour, minute: 0, second: 0}
  end

  def value_to_time({:value, {:partial_time, {hour}}}, :end) do
    %Time{hour: hour, minute: 59, second: 59}
  end

  def value_to_naive_datetime({:value, %NaiveDateTime{} = value}, _) do
    value
  end

  def value_to_naive_datetime({:value, %Date{} = date}, :start) do
    %NaiveDateTime{year: date.year, month: date.month, day: date.day, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_naive_datetime({:value, %Date{} = date}, :end) do
    %NaiveDateTime{year: date.year, month: date.month, day: date.day, hour: 23, minute: 59, second: 59, microsecond: {999999, 6}}
  end

  def value_to_naive_datetime({:value, {:partial_date, {year, month}}}, :start) do
    %NaiveDateTime{year: year, month: month, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_naive_datetime({:value, {:partial_date, {year}}}, :start) do
    %NaiveDateTime{year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_naive_datetime({:value, {:partial_date, {year, month}}}, :end) do
    Timex.end_of_month(%NaiveDateTime{year: year, month: month, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}})
  end

  def value_to_naive_datetime({:value, {:partial_date, {year}}}, :end) do
    Timex.end_of_year(%NaiveDateTime{year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}})
  end

  def value_to_naive_datetime({:value, {:partial_naive_datetime, date, time}}, range_point) do
    date = value_to_date({:value, date}, range_point)
    time = value_to_time({:value, time}, range_point)

    %NaiveDateTime{year: date.year, month: date.month, day: date.day,
                   hour: time.hour, minute: time.minute, second: time.second,
                   microsecond: time.microsecond}
  end

  def value_to_utc_datetime({:value, %NaiveDateTime{} = value}, _) do
    {:ok, datetime} = DateTime.from_naive(value, "Etc/UTC")
    datetime
  end

  def value_to_utc_datetime({:value, %DateTime{} = value}, _) do
    value
  end

  def value_to_utc_datetime({:value, %Date{} = date}, :start) do
    dt = DateTime.utc_now()
    %DateTime{dt | year: date.year, month: date.month, day: date.day, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_utc_datetime({:value, %Date{} = date}, :end) do
    dt = DateTime.utc_now()
    %DateTime{dt | year: date.year, month: date.month, day: date.day, hour: 23, minute: 59, second: 59, microsecond: {999999, 6}}
  end

  def value_to_utc_datetime({:value, {:partial_date, {year, month}}}, :start) do
    dt = DateTime.utc_now()
    %DateTime{dt | year: year, month: month, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_utc_datetime({:value, {:partial_date, {year}}}, :start) do
    dt = DateTime.utc_now()
    %DateTime{dt | year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_utc_datetime({:value, {:partial_date, {year, month}}}, :end) do
    dt = DateTime.utc_now()
    Timex.end_of_month(%DateTime{dt | year: year, month: month, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}})
  end

  def value_to_utc_datetime({:value, {:partial_date, {year}}}, :end) do
    dt = DateTime.utc_now()
    Timex.end_of_year(%DateTime{dt | year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}})
  end

  def value_to_utc_datetime({:value, {:partial_datetime, date, time}}, range_point) do
    date = value_to_date({:value, date}, range_point)
    time = value_to_time({:value, time}, range_point)

    dt = DateTime.utc_now()

    %{
      dt
      | year: date.year, month: date.month, day: date.day,
        hour: time.hour, minute: time.minute, second: time.second,
        microsecond: time.microsecond
    }
  end
end
