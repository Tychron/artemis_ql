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
  alias ArtemisQL.Errors.KeyNotFound
  alias ArtemisQL.Errors.InvalidEnumValue
  alias ArtemisQL.Errors.UnsupportedSearchTermForField

  import ArtemisQL.Tokens

  @type partial_date ::
    {:partial_date, {year::integer(), month::integer()}}
    | {:partial_date, {year::integer()}}

  @type partial_time ::
    {:partial_time, {hour::integer, minute::integer}}
    | {:partial_time, {hour::integer}}

  @type partial_datetime ::
    {:partial_datetime, Date.t(), partial_time()}

  @type partial_naive_datetime ::
    {:partial_naive_datetime, Date.t(), partial_time()}

  @type any_partial_datetime :: partial_datetime() | partial_date() | partial_time()

  @type any_partial_naive_datetime :: partial_naive_datetime() | partial_date() | partial_time()

  @doc """
  Attempts to filter the given key against the search_map, if the key is not in the map
  then :missing is returned, if the key is in the map but is being actively rejected, then
  :skip is returned instead.

  Otherwise the function returns the new atomized key as {:ok, atom}.
  """
  @spec allowed_key(String.t(), ArtemisQL.SearchMap.t()) :: :missing | :skip | {:ok, atom()}
  def allowed_key(key, %SearchMap{} = search_map) when is_binary(key) do
    case search_map.allowed_keys[key] do
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

  def allowed_key(
    key,
    search_map
  ) when is_binary(key) and is_atom(search_map) and not is_boolean(search_map) do
    case apply(search_map, :allowed_key, [key]) do
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
    handle_pair_transform(search_map.pair_transform[key], key, value, search_map)
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
        handle_pair_transform(other, key, value, search_map)
    end
  end

  def handle_pair_transform(type, key, r_group_token(items: [item]), search_map) do
    case handle_pair_transform(type, key, item, search_map) do
      {:ok, key, r_token() = value_token} ->
        {:ok, key, r_group_token(items: [value_token])}

      {:abort, reason} ->
        {:abort, reason}
    end
  end

  def handle_pair_transform(type, key, r_list_token(items: items), search_map) do
    {key, items} =
      Enum.reduce(items, {key, []}, fn value, {key, acc} ->
        case handle_pair_transform(type, key, value, search_map) do
          {:ok, key, r_token() = value} ->
            {key, [value | acc]}

          {:abort, reason} ->
            throw {:abort, reason}
        end
      end)

    {:ok, key, r_list_token(items: Enum.reverse(items))}
  end

  def handle_pair_transform(type, key, r_cmp_token(pair: {operator, value}, meta: meta), search_map) do
    case handle_pair_transform(type, key, value, search_map) do
      {:ok, key, r_token() = value} ->
        {:ok, key, r_cmp_token(pair: {operator, value}, meta: meta)}

      {:abort, reason} ->
        {:abort, reason}
    end
  end

  def handle_pair_transform(nil, key, r_token() = value, _search_map) do
    {:ok, key, value}
  end

  def handle_pair_transform({:type, module}, key, value, search_map) do
    handle_pair_transform({:type, module, []}, key, value, search_map)
  end

  def handle_pair_transform({:type, module, params}, key, value, search_map) do
    handle_type_module_transform(module, params, key, value, search_map)
  end

  def handle_pair_transform({:enum, module}, key, value, search_map) do
    handle_pair_transform({:enum, module, []}, key, value, search_map)
  end

  def handle_pair_transform({:enum, module, params}, key, value, search_map) do
    handle_enum_module_transform(module, params, key, value, search_map)
  end

  def handle_pair_transform({:apply, module, function_name, args}, key, value, _search_map) do
    :erlang.apply(module, function_name, [key, value | args])
  end

  def handle_pair_transform(function, key, value, _search_map) when is_function(function, 2) do
    function.(key, value)
  end

  @spec handle_type_module_transform(
    type::atom(),
    params::map(),
    key::atom(),
    value::any(),
    search_map::any()
  ) :: {:ok, key::atom(), token::any()}
     | {:error, term()}
  def handle_type_module_transform(:binary_id, _params, key, value, search_map) do
    case apply_to_value(value, &to_string/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:boolean, _params, key, value, search_map) do
    case apply_to_value(value, &to_boolean/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:integer, _params, key, value, search_map) do
    case apply_to_value(value, &String.to_integer/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:float, _params, key, value, search_map) do
    case apply_to_value(value, &String.to_float/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:decimal, _params, key, value, search_map) do
    case apply_to_value(value, &Decimal.new/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:atom, _params, key, value, search_map) do
    case apply_to_value(value, &String.to_existing_atom/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:string, _params, key, value, search_map) do
    case apply_to_value(value, &normalize_value/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:date, _params, key, value, search_map) do
    case apply_to_value(value, &parse_date/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:time, _params, key, value, search_map) do
    case apply_to_value(value, &parse_time/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:naive_datetime, _params, key, value, search_map) do
    case apply_to_value(value, &parse_naive_datetime/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:utc_datetime, _params, key, value, search_map) do
    case apply_to_value(value, &parse_datetime/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_enum_module_transform(enum, params, key, value, search_map) do
    value_from_enum(enum, params, key, value, search_map)
  end

  def value_from_enum(_enum, _params, key, r_null_token() = token, _search_map) do
    {:ok, key, token}
  end

  def value_from_enum(_enum, _params, key, r_any_char_token() = token, _search_map) do
    {:ok, key, token}
  end

  def value_from_enum(_enum, _params, key, r_wildcard_token() = token, _search_map) do
    {:ok, key, token}
  end

  def value_from_enum(enum, params, key, r_word_token(value: value, meta: meta) = token, search_map) do
    value_from_enum2(enum, params, key, token, r_value_token(value: value, meta: meta), search_map)
  end

  def value_from_enum(enum, params, key, r_quote_token(value: value, meta: meta) = token, search_map) do
    value_from_enum2(enum, params, key, token, r_value_token(value: value, meta: meta), search_map)
  end

  def value_from_enum(enum, params, key, r_value_token() = token, search_map) do
    value_from_enum2(enum, params, key, token, token, search_map)
  end

  def value_from_enum(enum, params, key, token, search_map) do
    reason =
      %UnsupportedSearchTermForField{
        meta: %{
          type: :enum,
          enum: enum,
          params: params,
        },
        key: key,
        token: token,
        search_map: search_map
      }

    {:abort, reason}
  end

  defp value_from_enum2(
    enum,
    params,
    key,
    org_token,
    r_value_token(value: value, meta: meta),
    search_map
  ) do
    value =
      if is_binary(value) do
        case Keyword.get(params, :normalize, false) do
          false ->
            value

          true ->
            String.downcase(value)
        end
      else
        value
      end

    case enum.cast(value) do
      {:ok, value} ->
        {:ok, key, r_value_token(value: value, meta: meta)}

      :error ->
        reason =
          %InvalidEnumValue{
            meta: %{
              type: :enum,
              enum: enum,
              params: params,
              value: value,
            },
            key: key,
            token: org_token,
            search_map: search_map,
          }

        {:abort, reason}
    end
  end

  @spec apply_to_value(token::any(), callback::any(), search_map::any()) ::
    {:ok, token::any()}
    | {:error, term()}
  def apply_to_value(
    r_pin_token(value: {kind, value, _}, meta: meta) = token,
    _callback,
    search_map
  ) when kind in [:word, :quote] do
    case allowed_key(value, search_map) do
      {:ok, value} when is_atom(value) ->
        {:ok, r_pin_token(value: value, meta: meta)}

      :skip ->
        {:error, {:unusuable_key_for_pin, value}}

      :missing ->
        reason = %KeyNotFound{
          meta: %{
            type: :pin,
          },
          token: token,
          search_map: search_map
        }
        {:error, reason}
    end
  end

  def apply_to_value(r_infinity_token() = token, _callback, _search_map) do
    {:ok, token}
  end

  def apply_to_value(r_wildcard_token() = token, _callback, _search_map) do
    {:ok, token}
  end

  def apply_to_value(r_null_token() = token, _callback, _search_map) do
    {:ok, token}
  end

  def apply_to_value(r_cmp_token(pair: {operator, value}, meta: meta), callback, search_map) do
    case apply_to_value(value, callback, search_map) do
      {:ok, value} ->
        {:ok, r_cmp_token(pair: {operator, value}, meta: meta)}

      {:error, _} = err ->
        err
    end
  end

  def apply_to_value({kind, value, meta}, callback, _search_map) when kind in [:word, :quote] do
    value = callback.(value)
    {:ok, r_value_token(value: value, meta: meta)}
  end

  def apply_to_value(r_partial_token(items: elements, meta: meta), callback, search_map) do
    {:ok, r_partial_token(items: Enum.map(elements, fn
      r_wildcard_token() = token ->
        token

      r_any_char_token() = token ->
        token

      {_kind, _value, _meta} = element ->
        case apply_to_value(element, callback, search_map) do
          {:ok, token} ->
            token

          {:error, _} = err ->
            throw err
        end
    end), meta: meta)}
  catch {:error, _reason} = err ->
    err
  end

  def apply_to_value(r_range_token(pair: {a, b}, meta: meta), callback, search_map) do
    with \
      {:ok, a_token} <- apply_to_value(a, callback, search_map),
      {:ok, b_token} <- apply_to_value(b, callback, search_map)
    do
      {:ok, r_range_token(
        pair: {a_token, b_token},
        meta: meta
      )}
    else
      {:error, _} = err ->
        err
    end
  end

  def parse_date(str) do
    parse_date(str, DateTime.utc_now())
  end

  def parse_date(str, now)

  def parse_date(<<"@",_::binary>> = str, now) do
    str
    |> parse_functional_time(now)
    |> DateTime.to_date()
  end

  def parse_date(str, _now) when is_binary(str) do
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

  @spec parse_time(String.t(), DateTime.t()) :: Time.t() | partial_time()
  def parse_time(str) do
    parse_time(str, DateTime.utc_now())
  end

  def parse_time(str, now)

  def parse_time(<<"@",_::binary>> = str, now) do
    str
    |> parse_functional_time(now)
    |> DateTime.to_time()
  end

  def parse_time(str, _now) when is_binary(str) do
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

  @spec parse_naive_datetime(String.t(), DateTime.t()) ::
    NaiveDateTime.t() | Date.t() | any_partial_naive_datetime()
  def parse_naive_datetime(str) do
    parse_naive_datetime(str, DateTime.utc_now())
  end

  def parse_naive_datetime(str, now)

  def parse_naive_datetime(<<"@",_::binary>> = str, now) do
    str
    |> parse_functional_time(now)
    |> DateTime.to_naive()
  end

  def parse_naive_datetime(str, now) when is_binary(str) do
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

                {:partial_naive_datetime, DateTime.to_date(now), time}

              [] ->
                parse_date(str)
            end
        end
    end
  rescue ex in ValueTransformError ->
    reraise %ValueTransformError{types: [:naive_datetime | ex.types]}, __STACKTRACE__
  end

  @spec parse_datetime(String.t(), DateTime.t()) ::
    DateTime.t() | Date.t() | any_partial_datetime()
  def parse_datetime(str) do
    parse_datetime(str, DateTime.utc_now())
  end

  def parse_datetime(str, now)

  def parse_datetime(<<"@",_::binary>> = str, now) do
    str
    |> parse_functional_time(now)
    |> DateTime.to_date()
  end

  def parse_datetime(str, now) when is_binary(str) do
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

                    {:partial_datetime, DateTime.to_date(now), time}

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
  def parse_functional_time(str) do
    parse_functional_time(str, DateTime.utc_now())
  end

  def parse_functional_time(<<"@", rest::binary>>, time_now) do
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
      |> do_parse_functional_time({duration, nil}, time_now)

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

  defp do_parse_functional_time([], {_duration, _anchor} = pair, _now) do
    pair
  end

  defp do_parse_functional_time(["from" | rest], {duration, _anchor}, now) do
    do_parse_functional_time(rest, {duration, {:from, nil}}, now)
  end

  defp do_parse_functional_time(["to" | rest], {duration, _anchor}, now) do
    do_parse_functional_time(rest, {duration, {:to, nil}}, now)
  end

  defp do_parse_functional_time(["till" | rest], {duration, _anchor}, now) do
    do_parse_functional_time(rest, {duration, {:to, nil}}, now)
  end

  defp do_parse_functional_time(["ago"], {duration, _anchor}, now) do
    do_parse_functional_time([], {duration, {:to, now}}, now)
  end

  defp do_parse_functional_time(["later"], {duration, _anchor}, now) do
    do_parse_functional_time([], {duration, {:from, now}}, now)
  end

  defp do_parse_functional_time([word, anchor_name], {duration, anchor}, now) when word in ["next"] do
    point =
      case anchor_name do
        "second" ->
          Timex.shift(now, seconds: 1)

        "minute" ->
          Timex.shift(now, minutes: 1)

        "hour" ->
          Timex.shift(now, hours: 1)

        "day" ->
          Timex.shift(now, days: 1)

        "week" ->
          Timex.shift(now, days: 7)

        "month" ->
          Timex.shift(now, months: 1)

        "year" ->
          Timex.shift(now, years: 1)
      end

    {duration, replace_anchor(anchor, point)}
  end

  defp do_parse_functional_time([word, anchor_name], {duration, anchor}, now) when word in ["last", "prev", "previous"] do
    point =
      case anchor_name do
        "second" ->
          Timex.shift(now, seconds: -1)

        "minute" ->
          Timex.shift(now, minutes: -1)

        "hour" ->
          Timex.shift(now, hours: -1)

        "day" ->
          Timex.shift(now, days: -1)

        "week" ->
          Timex.shift(now, days: -7)

        "month" ->
          Timex.shift(now, months: -1)

        "year" ->
          Timex.shift(now, years: -1)
      end

    {duration, replace_anchor(anchor, point)}
  end

  defp do_parse_functional_time([anchor_name], {duration, anchor}, now) do
    point =
      case anchor_name do
        "today" ->
          Timex.beginning_of_day(now)

        name when name in ["now"] ->
          now

        "yesterday" ->
          Timex.shift(now, days: -1)

        "tomorrow" ->
          Timex.shift(now, days: 1)
      end

    {duration, replace_anchor(anchor, point)}
  end

  defp do_parse_functional_time(["and" | rest], acc, now) do
    do_parse_functional_time(rest, acc, now)
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
    defp do_parse_functional_time([amount, unquote(to_string(unit)) | rest], {duration, anchor}, now) do
      duration = %{duration | unquote(unit) => duration.unquote(unit) + String.to_integer(amount, 10)}
      do_parse_functional_time(rest, {duration, anchor}, now)
    end

    defp do_parse_functional_time([amount, unquote(to_string(singular)) | rest], {duration, anchor}, now) do
      duration = %{duration | unquote(unit) => duration.unquote(unit) + String.to_integer(amount, 10)}
      do_parse_functional_time(rest, {duration, anchor}, now)
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
  # def value_to_date({:pin, _} = value, _) do
  #   value
  # end

  def value_to_date(r_value_token(value: %Date{} = date), _) do
    date
  end

  def value_to_date(r_value_token(value: {:partial_date, {year, month}}), :start) do
    %Date{year: year, month: month, day: 1}
  end

  def value_to_date(r_value_token(value: {:partial_date, {year, month}}), :end) do
    Timex.end_of_month(%Date{year: year, month: month, day: 1})
  end

  def value_to_date(r_value_token(value: {:partial_date, {year}}), :start) do
    Timex.beginning_of_year(year)
  end

  def value_to_date(r_value_token(value: {:partial_date, {year}}), :end) do
    Timex.end_of_year(year)
  end

  # def value_to_time({:pin, _} = value, _) do
  #   value
  # end

  def value_to_time(r_value_token(value: %Time{} = time), _) do
    time
  end

  def value_to_time(r_value_token(value: {:partial_time, {hour, minute}}), :start) do
    %Time{hour: hour, minute: minute, second: 0}
  end

  def value_to_time(r_value_token(value: {:partial_time, {hour, minute}}), :end) do
    %Time{hour: hour, minute: minute, second: 59}
  end

  def value_to_time(r_value_token(value: {:partial_time, {hour}}), :start) do
    %Time{hour: hour, minute: 0, second: 0}
  end

  def value_to_time(r_value_token(value: {:partial_time, {hour}}), :end) do
    %Time{hour: hour, minute: 59, second: 59}
  end

  # def value_to_naive_datetime({:pin, _} = value, _) do
  #   value
  # end

  def value_to_naive_datetime(r_value_token(value: %NaiveDateTime{} = value), _) do
    value
  end

  def value_to_naive_datetime(r_value_token(value: %Date{} = date), :start) do
    %NaiveDateTime{year: date.year, month: date.month, day: date.day, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_naive_datetime(r_value_token(value: %Date{} = date), :end) do
    %NaiveDateTime{year: date.year, month: date.month, day: date.day, hour: 23, minute: 59, second: 59, microsecond: {999999, 6}}
  end

  def value_to_naive_datetime(r_value_token(value: {:partial_date, {year, month}}), :start) do
    %NaiveDateTime{year: year, month: month, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_naive_datetime(r_value_token(value: {:partial_date, {year}}), :start) do
    %NaiveDateTime{year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_naive_datetime(r_value_token(value: {:partial_date, {year, month}}), :end) do
    Timex.end_of_month(%NaiveDateTime{year: year, month: month, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}})
  end

  def value_to_naive_datetime(r_value_token(value: {:partial_date, {year}}), :end) do
    Timex.end_of_year(%NaiveDateTime{year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}})
  end

  def value_to_naive_datetime(r_value_token(value: {:partial_naive_datetime, date, time}), range_point) do
    date = value_to_date(r_value_token(value: date), range_point)
    time = value_to_time(r_value_token(value: time), range_point)

    %NaiveDateTime{year: date.year, month: date.month, day: date.day,
                   hour: time.hour, minute: time.minute, second: time.second,
                   microsecond: time.microsecond}
  end

  # def value_to_utc_datetime({:pin, _} = value, _) do
  #   value
  # end

  def value_to_utc_datetime(r_value_token(value: %NaiveDateTime{} = value), _) do
    {:ok, datetime} = DateTime.from_naive(value, "Etc/UTC")
    datetime
  end

  def value_to_utc_datetime(r_value_token(value: %DateTime{} = value), _) do
    value
  end

  def value_to_utc_datetime(r_value_token(value: %Date{} = date), :start) do
    dt = DateTime.utc_now()
    %DateTime{dt | year: date.year, month: date.month, day: date.day, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_utc_datetime(r_value_token(value: %Date{} = date), :end) do
    dt = DateTime.utc_now()
    %DateTime{dt | year: date.year, month: date.month, day: date.day, hour: 23, minute: 59, second: 59, microsecond: {999999, 6}}
  end

  def value_to_utc_datetime(r_value_token(value: {:partial_date, {year, month}}), :start) do
    dt = DateTime.utc_now()
    %DateTime{dt | year: year, month: month, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_utc_datetime(r_value_token(value: {:partial_date, {year}}), :start) do
    dt = DateTime.utc_now()
    %DateTime{dt | year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  def value_to_utc_datetime(r_value_token(value: {:partial_date, {year, month}}), :end) do
    dt = DateTime.utc_now()
    Timex.end_of_month(%DateTime{dt | year: year, month: month, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}})
  end

  def value_to_utc_datetime(r_value_token(value: {:partial_date, {year}}), :end) do
    dt = DateTime.utc_now()
    Timex.end_of_year(%DateTime{dt | year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}})
  end

  def value_to_utc_datetime(r_value_token(value: {:partial_datetime, date, time}), range_point) do
    date = value_to_date(r_value_token(value: date), range_point)
    time = value_to_time(r_value_token(value: time), range_point)

    dt = DateTime.utc_now()

    %{
      dt
      | year: date.year, month: date.month, day: date.day,
        hour: time.hour, minute: time.minute, second: time.second,
        microsecond: time.microsecond
    }
  end

  def value_to_type_of(:date, token, range_point) do
    value_to_date(token, range_point)
  end

  def value_to_type_of(:time, token, range_point) do
    value_to_time(token, range_point)
  end

  def value_to_type_of(:naive_datetime, token, range_point) do
    value_to_naive_datetime(token, range_point)
  end

  def value_to_type_of(:utc_datetime, token, range_point) do
    value_to_utc_datetime(token, range_point)
  end
end
