defmodule ArtemisQL.Types do
  alias ArtemisQL.Types.ValueTransformError
  alias ArtemisQL.SearchMap
  alias ArtemisQL.Errors.KeyNotFound
  alias ArtemisQL.Errors.InvalidEnumValue
  alias ArtemisQL.Errors.UnsupportedSearchTermForField

  import ArtemisQL.Tokens

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
    case recast_token(value, &Ecto.Type.cast(:binary_id, &1), search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:uuid, _params, key, value, search_map) do
    case recast_token(value, &cast_uuid/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:ulid, _params, key, value, search_map) do
    case recast_token(value, &cast_ulid/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:boolean, _params, key, value, search_map) do
    case recast_token(value, &cast_boolean/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:integer, _params, key, value, search_map) do
    case recast_token(value, &Ecto.Type.cast(:integer, &1), search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:float, _params, key, value, search_map) do
    case recast_token(value, &Ecto.Type.cast(:float, &1), search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:decimal, _params, key, value, search_map) do
    case recast_token(value, &Ecto.Type.cast(:decimal, &1), search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:atom, _params, key, value, search_map) do
    case recast_token(value, &cast_atom/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:string, _params, key, value, search_map) do
    case recast_token(value, &normalize_value/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:date, _params, key, value, search_map) do
    case recast_token(value, &cast_date/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:time, _params, key, value, search_map) do
    case recast_token(value, &cast_time/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:naive_datetime, _params, key, value, search_map) do
    case recast_token(value, &cast_naive_datetime/1, search_map) do
      {:ok, token} ->
        {:ok, key, token}

      {:error, _} = err ->
        err
    end
  end

  def handle_type_module_transform(:utc_datetime, _params, key, value, search_map) do
    case recast_token(value, &cast_datetime/1, search_map) do
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

  @spec recast_token(token::any(), callback::any(), search_map::any()) ::
    {:ok, token::any()}
    | {:error, term()}
  def recast_token(
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

  def recast_token(r_infinity_token() = token, _callback, _search_map) do
    {:ok, token}
  end

  def recast_token(r_wildcard_token() = token, _callback, _search_map) do
    {:ok, token}
  end

  def recast_token(r_null_token() = token, _callback, _search_map) do
    {:ok, token}
  end

  def recast_token(r_cmp_token(pair: {operator, value}, meta: meta), callback, search_map) do
    case recast_token(value, callback, search_map) do
      {:ok, value} ->
        {:ok, r_cmp_token(pair: {operator, value}, meta: meta)}

      {:error, _} = err ->
        err
    end
  end

  def recast_token({kind, value, meta}, callback, _search_map) when kind in [:word, :quote] do
    case callback.(value) do
      {:ok, value} ->
        {:ok, r_value_token(value: value, meta: meta)}

      :error ->
        {:error, :cast_error}
    end
  end

  def recast_token(r_partial_token(items: elements, meta: meta), callback, search_map) do
    {:ok, r_partial_token(items: Enum.map(elements, fn
      r_wildcard_token() = token ->
        token

      r_any_char_token() = token ->
        token

      {_kind, _value, _meta} = element ->
        case recast_token(element, callback, search_map) do
          {:ok, token} ->
            token

          {:error, _} = err ->
            throw err
        end
    end), meta: meta)}
  catch {:error, _reason} = err ->
    err
  end

  def recast_token(r_range_token(pair: {a, b}, meta: meta), callback, search_map) do
    with \
      {:ok, a_token} <- recast_token(a, callback, search_map),
      {:ok, b_token} <- recast_token(b, callback, search_map)
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

  def normalize_value(value) do
    {:ok, value}
  end

  @spec cast_uuid(binary()) :: {:ok, String.t()} | :error
  def cast_uuid(str) do
    Ecto.UUID.cast(str)
  end

  @spec cast_ulid(binary()) :: {:ok, String.t()} | :error
  def cast_ulid(str) do
    Ecto.ULID.cast(str)
  end

  @spec cast_boolean(String.t()) :: {:ok, boolean()}
  def cast_boolean(value) when is_binary(value) do
    case String.downcase(value) do
      v when v in ~w[yes y 1 true t on] ->
        {:ok, true}

      v when v in ~w[no n 0 false f off] ->
        {:ok, false}

      _ ->
        :error
    end
  end

  @spec cast_atom(String.t()) :: {:ok, atom()}
  def cast_atom(str) do
    {:ok, String.to_existing_atom(str)}
  end

  @spec cast_date(String.t()) :: {:ok, Date.t()}
  def cast_date(value) do
    {:ok, ArtemisQL.Types.DateAndTime.parse_date(value)}
  rescue _ex in ValueTransformError ->
    :error
  end

  @spec cast_time(String.t()) :: {:ok, Time.t()}
  def cast_time(value) do
    {:ok, ArtemisQL.Types.DateAndTime.parse_time(value)}
  rescue _ex in ValueTransformError ->
    :error
  end

  @spec cast_datetime(String.t()) :: {:ok, Time.t()}
  def cast_datetime(value) do
    {:ok, ArtemisQL.Types.DateAndTime.parse_datetime(value)}
  rescue _ex in ValueTransformError ->
    :error
  end

  @spec cast_naive_datetime(String.t()) :: {:ok, Time.t()}
  def cast_naive_datetime(value) do
    {:ok, ArtemisQL.Types.DateAndTime.parse_naive_datetime(value)}
  rescue _ex in ValueTransformError ->
    :error
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
