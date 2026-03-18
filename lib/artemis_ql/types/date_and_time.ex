defmodule ArtemisQL.Types.DateAndTime do
  alias ArtemisQL.Types.ValueTransformError

  @type partial_date ::
          {:partial_date, {year :: integer(), month :: integer()}}
          | {:partial_date, {year :: integer()}}

  @type partial_time ::
          {:partial_time, {hour :: integer, minute :: integer}}
          | {:partial_time, {hour :: integer}}

  @type partial_datetime ::
          {:partial_datetime, Date.t(), partial_time()}

  @type partial_naive_datetime ::
          {:partial_naive_datetime, Date.t(), partial_time()}

  @type any_partial_datetime :: partial_datetime() | partial_date() | partial_time()

  @type any_partial_naive_datetime :: partial_naive_datetime() | partial_date() | partial_time()

  @spec parse_date(str :: String.t(), DateTime.t()) :: Date.t()
  def parse_date(str) do
    parse_date(str, DateTime.utc_now())
  end

  def parse_date(str, now)

  def parse_date(<<"@", _::binary>> = str, now) do
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

  def parse_time(<<"@", _::binary>> = str, now) do
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

  def parse_naive_datetime(<<"@", _::binary>> = str, now) do
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
            year::binary-size(4),
            "-",
            month::binary-size(2),
            "-",
            day::binary-size(2),
            "T",
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
  rescue
    ex in ValueTransformError ->
      reraise %ValueTransformError{types: [:naive_datetime | ex.types]}, __STACKTRACE__
  end

  @spec parse_datetime(String.t(), DateTime.t()) ::
          DateTime.t() | Date.t() | any_partial_datetime()
  def parse_datetime(str) do
    parse_datetime(str, DateTime.utc_now())
  end

  def parse_datetime(str, now)

  def parse_datetime(<<"@", rest::binary>>, now) do
    spec = parse_functional_time_alias_spec!(rest)
    datetime = apply_functional_time_spec(spec, now)

    if day_wide_datetime_alias?(spec) do
      DateTime.to_date(datetime)
    else
      datetime
    end
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
                year::binary-size(4),
                "-",
                month::binary-size(2),
                "-",
                day::binary-size(2),
                "T",
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
  rescue
    ex in ValueTransformError ->
      reraise %ValueTransformError{types: [:datetime | ex.types]}, __STACKTRACE__
  end

  @doc """
  """
  @spec parse_keyword_datetime!(String.t()) :: DateTime.t()
  def parse_keyword_datetime!(str) do
    parse_keyword_datetime!(str, DateTime.utc_now())
  end

  def parse_keyword_datetime!(<<"@", rest::binary>>, time_now) do
    rest
    |> parse_functional_time_alias_spec!()
    |> apply_functional_time_spec(time_now)
  end

  defp apply_functional_time_spec(
         %{duration: duration, direction: direction, anchor: anchor_ref},
         now
       ) do
    anchor = resolve_anchor(anchor_ref, now)

    case direction do
      :point ->
        anchor

      :from ->
        Timex.shift(anchor, build_timex_shift(duration, 1))

      :to ->
        Timex.shift(anchor, build_timex_shift(duration, -1))
    end
  end

  defp resolve_anchor({:absolute, :today}, now) do
    Timex.beginning_of_day(now)
  end

  defp resolve_anchor({:absolute, :now}, now) do
    now
  end

  defp resolve_anchor({:absolute, :yesterday}, now) do
    Timex.shift(now, days: -1)
  end

  defp resolve_anchor({:absolute, :tomorrow}, now) do
    Timex.shift(now, days: 1)
  end

  defp resolve_anchor({:relative, :next, unit}, now) do
    {key, offset} = unit_to_shift(unit)
    Timex.shift(now, [{key, offset}])
  end

  defp resolve_anchor({:relative, :last, unit}, now) do
    {key, offset} = unit_to_shift(unit)
    Timex.shift(now, [{key, -offset}])
  end

  defp parse_functional_time_alias_spec!(rest) when is_binary(rest) do
    case ArtemisQL.Types.FunctionalTimeAliasParser.parse(rest) do
      {:ok, spec} ->
        spec

      :error ->
        raise %ValueTransformError{types: [:functional_time]}
    end
  end

  defp day_wide_datetime_alias?(%{
         duration: duration,
         direction: :point,
         anchor: {:absolute, anchor}
       })
       when anchor in [:today, :now, :yesterday, :tomorrow] do
    Enum.all?(duration, fn {_unit, value} -> value == 0 end)
  end

  defp day_wide_datetime_alias?(_), do: false

  defp build_timex_shift(duration, multiplier) do
    years =
      duration.years +
        duration.decades * 10 +
        duration.centuries * 100 +
        duration.millennia * 1000

    [
      seconds: duration.seconds * multiplier,
      minutes: duration.minutes * multiplier,
      hours: duration.hours * multiplier,
      days: (duration.days + duration.weeks * 7) * multiplier,
      months: duration.months * multiplier,
      years: years * multiplier
    ]
  end

  defp unit_to_shift(:seconds), do: {:seconds, 1}
  defp unit_to_shift(:minutes), do: {:minutes, 1}
  defp unit_to_shift(:hours), do: {:hours, 1}
  defp unit_to_shift(:days), do: {:days, 1}
  defp unit_to_shift(:weeks), do: {:days, 7}
  defp unit_to_shift(:months), do: {:months, 1}
  defp unit_to_shift(:years), do: {:years, 1}
  defp unit_to_shift(:decades), do: {:years, 10}
  defp unit_to_shift(:centuries), do: {:years, 100}
  defp unit_to_shift(:millennia), do: {:years, 1000}
end
