defmodule ArtemisQL.RandomTest do
  use ExUnit.Case, async: true

  describe "random_boolean/0" do
    test "can generate a random boolean" do
      assert is_boolean(ArtemisQL.Random.random_boolean())
    end
  end

  describe "random_time/0" do
    test "can safely generate a random time" do
      assert %Time{} = ArtemisQL.Random.random_time()
    end
  end

  describe "random_date/0" do
    test "can safely generate a random date" do
      assert %Date{} = ArtemisQL.Random.random_date()
    end
  end

  describe "random_datetime/0" do
    test "can safely generate a random datetime" do
      assert %DateTime{} = ArtemisQL.Random.random_datetime()
    end
  end

  describe "random_naive_datetime/0" do
    test "can safely generate a random naive datetime" do
      assert %NaiveDateTime{} = ArtemisQL.Random.random_naive_datetime()
    end
  end
end
