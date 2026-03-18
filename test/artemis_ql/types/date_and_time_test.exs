defmodule ArtemisQL.Types.DateAndTimeTest do
  use ExUnit.Case

  alias ArtemisQL.Types.DateAndTime, as: Subject

  describe "parse_date/1" do
    test "can parse a whole date string" do
      assert %Date{year: 2020, month: 10, day: 1} == Subject.parse_date("2020-10-01")
    end

    test "can parse a partial date string (YYYY-MM)" do
      assert {:partial_date, {2020, 10}} == Subject.parse_date("2020-10")
    end

    test "can parse a partial date string (YYYY)" do
      assert {:partial_date, {2020}} == Subject.parse_date("2020")
    end
  end

  describe "parse_time/1" do
    test "can parse a partial time" do
      assert %Time{hour: 11, minute: 48, second: 15} == Subject.parse_time("11:48:15")
    end

    test "can parse a partial time (HH:MM)" do
      assert {:partial_time, {11, 48}} == Subject.parse_time("11:48")
    end

    test "can parse a partial time (HH)" do
      assert {:partial_time, {11}} == Subject.parse_time("11")
      assert {:partial_time, {1}} == Subject.parse_time("1")
      assert {:partial_time, {1}} == Subject.parse_time("01")
    end
  end

  describe "parse_keyword_datetime!/1" do
    test "can handle several keywords" do
      now = DateTime.utc_now()

      assert %DateTime{now | hour: 0, minute: 0, second: 0, microsecond: {0, 6}} ==
               Subject.parse_keyword_datetime!("@today", now)

      assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@now", now), now)

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@yesterday", now),
                 Timex.shift(now, days: -1)
               )

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@tomorrow", now),
                 Timex.shift(now, days: 1)
               )
    end

    test "can handle ago and till-now and later suffix" do
      now = DateTime.utc_now()

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@6-hours-till-now", now),
                 Timex.shift(now, hours: -6)
               )

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@6-hours-ago", now),
                 Timex.shift(now, hours: -6)
               )

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@6-hours-later", now),
                 Timex.shift(now, hours: 6)
               )
    end

    test "works with period words" do
      now = DateTime.utc_now()

      for period <- [
            "second",
            "minute",
            "hour",
            "day",
            "week",
            "month",
            "year",
            "decade",
            "century",
            "millennium"
          ] do
        {shift_id, mult} =
          case period do
            "second" -> {:seconds, 1}
            "minute" -> {:minutes, 1}
            "hour" -> {:hours, 1}
            "day" -> {:days, 1}
            "week" -> {:days, 7}
            "month" -> {:months, 1}
            "year" -> {:years, 1}
            "decade" -> {:years, 10}
            "century" -> {:years, 100}
            "millennium" -> {:years, 1000}
          end

        assert :eq ==
                 DateTime.compare(
                   Subject.parse_keyword_datetime!("@next-#{period}", now),
                   Timex.shift(now, [{shift_id, 1 * mult}])
                 )

        assert :eq ==
                 DateTime.compare(
                   Subject.parse_keyword_datetime!("@prev-#{period}", now),
                   Timex.shift(now, [{shift_id, -1 * mult}])
                 )

        assert :eq ==
                 DateTime.compare(
                   Subject.parse_keyword_datetime!("@last-#{period}", now),
                   Timex.shift(now, [{shift_id, -1 * mult}])
                 )

        assert :eq ==
                 DateTime.compare(
                   Subject.parse_keyword_datetime!("@previous-#{period}", now),
                   Timex.shift(now, [{shift_id, -1 * mult}])
                 )
      end

      assert %DateTime{} =
               Subject.parse_keyword_datetime!(
                 "@3-days-and-2-weeks-and-1-month-and-1-year-from-last-week"
               )
    end

    test "works with amount-based long period words" do
      now = DateTime.utc_now()

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@1-decade-ago", now),
                 Timex.shift(now, years: -10)
               )

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@1-century-ago", now),
                 Timex.shift(now, years: -100)
               )

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@1-millennium-ago", now),
                 Timex.shift(now, years: -1000)
               )
    end

    test "works with relative amount aliases" do
      now = DateTime.utc_now()

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@last-24-hours", now),
                 Timex.shift(now, hours: -24)
               )

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@next-24-hours", now),
                 Timex.shift(now, hours: 24)
               )

      assert :eq ==
               DateTime.compare(
                 Subject.parse_keyword_datetime!("@last-24-days-and-3-hours", now),
                 Timex.shift(now, days: -24, hours: -3)
               )
    end

    test "property: relative aliases match explicit ago/later rewrites" do
      now = ~U[2026-01-01 12:34:56.123456Z]
      :rand.seed(:exsplus, {101, 202, 303})

      units = [
        "seconds",
        "minutes",
        "hours",
        "days",
        "weeks",
        "months",
        "years"
      ]

      Enum.each(1..200, fn _ ->
        chain = random_duration_chain(units)

        assert :eq ==
                 DateTime.compare(
                   Subject.parse_keyword_datetime!("@last-#{chain}", now),
                   Subject.parse_keyword_datetime!("@#{chain}-ago", now)
                 )

        assert :eq ==
                 DateTime.compare(
                   Subject.parse_keyword_datetime!("@prev-#{chain}", now),
                   Subject.parse_keyword_datetime!("@#{chain}-ago", now)
                 )

        assert :eq ==
                 DateTime.compare(
                   Subject.parse_keyword_datetime!("@previous-#{chain}", now),
                   Subject.parse_keyword_datetime!("@#{chain}-ago", now)
                 )

        assert :eq ==
                 DateTime.compare(
                   Subject.parse_keyword_datetime!("@next-#{chain}", now),
                   Subject.parse_keyword_datetime!("@#{chain}-later", now)
                 )
      end)
    end

    test "raises ValueTransformError for invalid alias forms" do
      assert_raise ArtemisQL.Types.ValueTransformError, fn ->
        Subject.parse_keyword_datetime!("@last-24-hour-")
      end
    end
  end

  describe "parse_datetime/1" do
    test "returns a date for absolute @ keyword inputs" do
      date = Date.utc_today()
      assert date == Subject.parse_datetime("@now")
      assert date == Subject.parse_datetime("@today")
      yesterday = Timex.shift(Date.utc_today(), days: -1)
      assert yesterday == Subject.parse_datetime("@yesterday")
      tomorrow = Timex.shift(Date.utc_today(), days: +1)
      assert tomorrow == Subject.parse_datetime("@tomorrow")
    end

    test "returns datetime for relative @ keyword inputs" do
      now = ~U[2026-01-01 12:34:56.123456Z]

      assert %DateTime{} = Subject.parse_datetime("@last-24-hours", now)

      assert :eq ==
               DateTime.compare(
                 Subject.parse_datetime("@last-24-hours", now),
                 Timex.shift(now, hours: -24)
               )
    end
  end

  defp random_duration_chain(units) when is_list(units) do
    segment_count = :rand.uniform(4)

    1..segment_count
    |> Enum.map(fn _ ->
      amount = :rand.uniform(12)
      unit = Enum.at(units, :rand.uniform(length(units)) - 1)
      "#{amount}-#{unit}"
    end)
    |> Enum.join("-and-")
  end
end
