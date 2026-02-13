defmodule ArtemisQL.UtilsTest do
  use ExUnit.Case, async: true

  describe "parse_integer/1" do
    test "can parse an integer" do
      assert {:ok, 0} == ArtemisQL.Utils.parse_integer("0")
      assert {:ok, 0} == ArtemisQL.Utils.parse_integer("0b0")
      assert {:ok, 0} == ArtemisQL.Utils.parse_integer("0o0")
      assert {:ok, 0} == ArtemisQL.Utils.parse_integer("0x0")

      #
      assert {:ok, 1_2_34_567_8_9_0} == ArtemisQL.Utils.parse_integer("1_2_34_567_8_9_0")
      assert {:ok, 0b00_11_11_11_111} == ArtemisQL.Utils.parse_integer("0b00_11_11_11_111")
      assert {:ok, 0o76_54_32_10} == ArtemisQL.Utils.parse_integer("0o76_54_32_10")
      assert {:ok, 0xFE_EC_BA_98_76_54_32_10} == ArtemisQL.Utils.parse_integer("0xFE_EC_BA_98_76_54_32_10")
    end
  end

  describe "normalize_decimal_string/1" do
    test "can normalize a decimal string" do
      assert {:ok, "1000.000"} == ArtemisQL.Utils.normalize_decimal_string("1_000.000")
      assert {:ok, "1e2"} == ArtemisQL.Utils.normalize_decimal_string("1e2")
      assert {:ok, "1e+2"} == ArtemisQL.Utils.normalize_decimal_string("1e+2")
      assert {:ok, "1.0e+2"} == ArtemisQL.Utils.normalize_decimal_string("1.0e+2")
      assert {:ok, "-1e+2"} == ArtemisQL.Utils.normalize_decimal_string("-1e+2")
      assert {:ok, "-.5"} == ArtemisQL.Utils.normalize_decimal_string("-.5")
    end
  end
end
