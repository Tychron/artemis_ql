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
      assert %DateTime{hour: 0, minute: 0, second: 0} = Types.parse_functional_time("@today")
      assert %DateTime{} = Types.parse_functional_time("@now")
      assert %DateTime{} = Types.parse_functional_time("@yesterday")
      assert %DateTime{} = Types.parse_functional_time("@tomorrow")

      for period <- ["day", "week", "month", "year"] do
        assert %DateTime{} = Types.parse_functional_time("@next-#{period}")
        assert %DateTime{} = Types.parse_functional_time("@prev-#{period}")
        assert %DateTime{} = Types.parse_functional_time("@last-#{period}")
        assert %DateTime{} = Types.parse_functional_time("@previous-#{period}")
      end

      assert %DateTime{} = Types.parse_functional_time("@3-days-and-2-weeks-and-1-month-and-1-year-from-last-week")
    end
  end
end
