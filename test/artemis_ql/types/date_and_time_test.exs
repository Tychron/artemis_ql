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

      assert %DateTime{now | hour: 0, minute: 0, second: 0, microsecond: {0, 6}} == Subject.parse_keyword_datetime!("@today", now)
      assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@now", now), now)
      assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@yesterday", now), Timex.shift(now, days: -1))
      assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@tomorrow", now), Timex.shift(now, days: 1))
    end

    test "can handle ago and till-now and later suffix" do
      now = DateTime.utc_now()

      assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@6-hours-till-now", now), Timex.shift(now, hours: -6))
      assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@6-hours-ago", now), Timex.shift(now, hours: -6))
      assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@6-hours-later", now), Timex.shift(now, hours: 6))
    end

    test "works with period words" do
      now = DateTime.utc_now()

      for period <- ["second", "minute", "hour", "day", "week", "month", "year", "century", "millennium"] do
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

        assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@next-#{period}", now), Timex.shift(now, [{shift_id, 1 * mult}]))
        assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@prev-#{period}", now), Timex.shift(now, [{shift_id, -1 * mult}]))
        assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@last-#{period}", now), Timex.shift(now, [{shift_id, -1 * mult}]))
        assert :eq == DateTime.compare(Subject.parse_keyword_datetime!("@previous-#{period}", now), Timex.shift(now, [{shift_id, -1 * mult}]))
      end

      assert %DateTime{} = Subject.parse_keyword_datetime!("@3-days-and-2-weeks-and-1-month-and-1-year-from-last-week")
    end
  end
end
