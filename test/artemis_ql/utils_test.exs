defmodule ArtemisQL.UtilsTest do
  use ExUnit.Case, async: true

  alias ArtemisQL.Utils

  describe "parse_integer/1" do
    test "can parse an integer" do
      assert {:ok, 0} == Utils.parse_integer("0")
      assert {:ok, 0} == Utils.parse_integer("0b0")
      assert {:ok, 0} == Utils.parse_integer("0o0")
      assert {:ok, 0} == Utils.parse_integer("0x0")

      #
      assert {:ok, 1_2_34_567_8_9_0} == Utils.parse_integer("1_2_34_567_8_9_0")
      assert {:ok, 0b00_11_11_11_111} == Utils.parse_integer("0b00_11_11_11_111")
      assert {:ok, 0o76_54_32_10} == Utils.parse_integer("0o76_54_32_10")
      assert {:ok, 0xFE_EC_BA_98_76_54_32_10} == Utils.parse_integer("0xFE_EC_BA_98_76_54_32_10")
    end
  end

  describe "normalize_decimal_string/1" do
    test "can normalize a decimal string" do
      assert {:ok, "1000.000"} == Utils.normalize_decimal_string("1_000.000")
      assert {:ok, "1e2"} == Utils.normalize_decimal_string("1e2")
      assert {:ok, "1e+2"} == Utils.normalize_decimal_string("1e+2")
      assert {:ok, "1.0e+2"} == Utils.normalize_decimal_string("1.0e+2")
      assert {:ok, "-1e+2"} == Utils.normalize_decimal_string("-1e+2")
      assert {:ok, "-.5"} == Utils.normalize_decimal_string("-.5")
    end
  end

  describe "beginning_of_day/1" do
    test "changes the time part of the given datetime struct to the beginning of the day" do
      datetime = DateTime.utc_now()
      assert %DateTime{
        datetime
        | hour: 0, minute: 0, second: 0, microsecond: {0, 6}
      } == Utils.beginning_of_day(datetime)
    end

    test "changes the time part of the given naive_datetime struct to the beginning of the day" do
      datetime = NaiveDateTime.utc_now()
      assert %NaiveDateTime{
        datetime
        | hour: 0, minute: 0, second: 0, microsecond: {0, 6}
      } == Utils.beginning_of_day(datetime)
    end

    test "changes given time struct to the beginning of the day" do
      time = Time.utc_now()
      assert %Time{
        time
        | hour: 0, minute: 0, second: 0, microsecond: {0, 6}
      } == Utils.beginning_of_day(time)
    end

    test "returns date as-is" do
      date = Date.utc_today()
      assert date == Utils.beginning_of_day(date)
    end
  end
end
