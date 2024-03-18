defmodule ArtemisQL.Types.DateAndTime do
  alias ArtemisQL.Types.ValueTransformError

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

  @spec parse_date(str::String.t(), DateTime.t()) :: Date.t()
  def parse_date(str) do
    parse_date(str, DateTime.utc_now())
  end

  def parse_date(str, now)

  def parse_date(<<"@",_::binary>> = str, now) do
    str
    |> parse_keyword_datetime!(now)
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
    |> parse_keyword_datetime!(now)
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
    |> parse_keyword_datetime!(now)
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
    |> parse_keyword_datetime!(now)
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
  @spec parse_keyword_datetime!(String.t()) :: DateTime.t()
  def parse_keyword_datetime!(str) do
    parse_keyword_datetime!(str, DateTime.utc_now())
  end

  def parse_keyword_datetime!(<<"@", rest::binary>>, time_now) do
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
      |> do_parse_keyword_datetime({duration, nil}, time_now)

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

  defp do_parse_keyword_datetime([], {_duration, _anchor} = pair, _now) do
    pair
  end

  defp do_parse_keyword_datetime(["from" | rest], {duration, _anchor}, now) do
    do_parse_keyword_datetime(rest, {duration, {:from, nil}}, now)
  end

  defp do_parse_keyword_datetime(["to" | rest], {duration, _anchor}, now) do
    do_parse_keyword_datetime(rest, {duration, {:to, nil}}, now)
  end

  defp do_parse_keyword_datetime(["till" | rest], {duration, _anchor}, now) do
    do_parse_keyword_datetime(rest, {duration, {:to, nil}}, now)
  end

  defp do_parse_keyword_datetime(["ago"], {duration, _anchor}, now) do
    do_parse_keyword_datetime([], {duration, {:to, now}}, now)
  end

  defp do_parse_keyword_datetime(["later"], {duration, _anchor}, now) do
    do_parse_keyword_datetime([], {duration, {:from, now}}, now)
  end

  defp do_parse_keyword_datetime([word, anchor_name], {duration, anchor}, now) when word in ["next"] do
    {key, offset} = anchor_to_key_and_offset(anchor_name)
    point = Timex.shift(now, [{key, offset}])

    {duration, replace_anchor(anchor, point)}
  end

  defp do_parse_keyword_datetime([word, anchor_name], {duration, anchor}, now) when word in ["last", "prev", "previous"] do
    {key, offset} = anchor_to_key_and_offset(anchor_name)
    point = Timex.shift(now, [{key, offset * -1}])

    {duration, replace_anchor(anchor, point)}
  end

  defp do_parse_keyword_datetime([anchor_name], {duration, anchor}, now) do
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

  defp do_parse_keyword_datetime(["and" | rest], acc, now) do
    do_parse_keyword_datetime(rest, acc, now)
  end

  rows = [
    {:second, :seconds},
    {:minute, :minutes},
    {:hour, :hours},
    {:day, :days},
    {:week, :weeks},
    {:month, :months},
    {:year, :years},
    {:decade, :decades},
    {:century, :centuries},
    {:millennium, :millennia},
  ]

  for {singular, unit} <- rows do
    defp do_parse_keyword_datetime([amount, unquote(to_string(unit)) | rest], {duration, anchor}, now) do
      duration = %{duration | unquote(unit) => duration.unquote(unit) + String.to_integer(amount, 10)}
      do_parse_keyword_datetime(rest, {duration, anchor}, now)
    end

    defp do_parse_keyword_datetime([amount, unquote(to_string(singular)) | rest], {duration, anchor}, now) do
      duration = %{duration | unquote(unit) => duration.unquote(unit) + String.to_integer(amount, 10)}
      do_parse_keyword_datetime(rest, {duration, anchor}, now)
    end
  end

  @spec anchor_to_key_and_offset(String.t() | atom()) :: {atom(), integer()}
  for {singular, unit} <- rows do
    defp anchor_to_key_and_offset(unquote(to_string(singular))), do: anchor_to_key_and_offset(unquote(unit))
    defp anchor_to_key_and_offset(unquote(to_string(unit))), do: anchor_to_key_and_offset(unquote(unit))
    defp anchor_to_key_and_offset(unquote(singular)), do: anchor_to_key_and_offset(unquote(unit))
  end

  defp anchor_to_key_and_offset(:seconds), do: {:seconds, 1}
  defp anchor_to_key_and_offset(:minutes), do: {:minutes, 1}
  defp anchor_to_key_and_offset(:hours), do: {:hours, 1}
  defp anchor_to_key_and_offset(:days), do: {:days, 1}
  defp anchor_to_key_and_offset(:weeks), do: {:days, 7}
  defp anchor_to_key_and_offset(:months), do: {:months, 1}
  defp anchor_to_key_and_offset(:years), do: {:years, 1}
  defp anchor_to_key_and_offset(:decades), do: {:years, 10}
  defp anchor_to_key_and_offset(:centuries), do: {:years, 100}
  defp anchor_to_key_and_offset(:millennia), do: {:years, 1000}

  defp replace_anchor({direction, _}, value) do
    {direction, value}
  end

  defp replace_anchor(nil, value) do
    value
  end
end
