defmodule ArtemisQL.TypesTest do
  use ExUnit.Case

  alias ArtemisQL.Types

  describe "parse_date/1" do
    test "can parse a whole date string" do
      assert %Date{year: 2020, month: 10, day: 1} == Types.parse_date("2020-10-01")
    end

    test "can parse a partial date string (YYYY-MM)" do
      assert {:partial_date, {2020, 10}} == Types.parse_date("2020-10")
    end

    test "can parse a partial date string (YYYY)" do
      assert {:partial_date, {2020}} == Types.parse_date("2020")
    end
  end

  describe "parse_time/1" do
    test "can parse a partial time" do
      assert %Time{hour: 11, minute: 48, second: 15} == Types.parse_time("11:48:15")
    end

    test "can parse a partial time (HH:MM)" do
      assert {:partial_time, {11, 48}} == Types.parse_time("11:48")
    end

    test "can parse a partial time (HH)" do
      assert {:partial_time, {11}} == Types.parse_time("11")
      assert {:partial_time, {1}} == Types.parse_time("1")
      assert {:partial_time, {1}} == Types.parse_time("01")
    end
  end

  describe "parse_functional_time/1" do
    test "can handle several keywords" do
      now = DateTime.utc_now()

      assert %DateTime{now | hour: 0, minute: 0, second: 0, microsecond: {0, 6}} == Types.parse_functional_time("@today", now)
      assert :eq == DateTime.compare(Types.parse_functional_time("@now", now), now)
      assert :eq == DateTime.compare(Types.parse_functional_time("@yesterday", now), Timex.shift(now, days: -1))
      assert :eq == DateTime.compare(Types.parse_functional_time("@tomorrow", now), Timex.shift(now, days: 1))
    end

    test "can handle ago and till-now and later suffix" do
      now = DateTime.utc_now()

      assert :eq == DateTime.compare(Types.parse_functional_time("@6-hours-till-now", now), Timex.shift(now, hours: -6))
      assert :eq == DateTime.compare(Types.parse_functional_time("@6-hours-ago", now), Timex.shift(now, hours: -6))
      assert :eq == DateTime.compare(Types.parse_functional_time("@6-hours-later", now), Timex.shift(now, hours: 6))
    end

    test "works with period words" do
      now = DateTime.utc_now()

      for period <- ["hour", "day", "week", "month", "year"] do
        {shift_id, mult} =
          case period do
            "hour" -> {:hours, 1}
            "day" -> {:days, 1}
            "week" -> {:days, 7}
            "month" -> {:months, 1}
            "year" -> {:years, 1}
          end

        assert :eq == DateTime.compare(Types.parse_functional_time("@next-#{period}", now), Timex.shift(now, [{shift_id, 1 * mult}]))
        assert :eq == DateTime.compare(Types.parse_functional_time("@prev-#{period}", now), Timex.shift(now, [{shift_id, -1 * mult}]))
        assert :eq == DateTime.compare(Types.parse_functional_time("@last-#{period}", now), Timex.shift(now, [{shift_id, -1 * mult}]))
        assert :eq == DateTime.compare(Types.parse_functional_time("@previous-#{period}", now), Timex.shift(now, [{shift_id, -1 * mult}]))
      end

      assert %DateTime{} = Types.parse_functional_time("@3-days-and-2-weeks-and-1-month-and-1-year-from-last-week")
    end
  end
end
