defmodule ArtemisQL.HelpersTest do
  use ExUnit.Case

  alias ArtemisQL.Helpers

  import ArtemisQL.Tokens

  describe "partial_to_regex/1" do
    test "can convert a partial to a regular expression" do
      {:ok, [r_partial_token(items: items)], ""} = ArtemisQL.decode("All*")

      assert {:ok, regex} = Helpers.partial_to_regex(items)

      assert String.match?("All", regex)
      assert String.match?("Allabaster", regex)
      refute String.match?("Nall", regex)
    end
  end

  describe "string_matches_partial?/2" do
    test "can match a string against a simple partial value" do
      {:ok, [r_partial_token(items: items)], ""} = ArtemisQL.decode("All*")

      assert Helpers.string_matches_partial?("All", items)
      assert Helpers.string_matches_partial?("Allow", items)
      assert Helpers.string_matches_partial?("Allstar", items)
      assert Helpers.string_matches_partial?("Allabaster", items)
      refute Helpers.string_matches_partial?("Aliman", items)

      {:ok, [r_partial_token(items: items)], ""} = ArtemisQL.decode("*end")

      assert Helpers.string_matches_partial?("Upend", items)
      assert Helpers.string_matches_partial?("Prepend", items)
      assert Helpers.string_matches_partial?("Append", items)
      assert Helpers.string_matches_partial?("end", items)
      assert Helpers.string_matches_partial?("rend", items)
      assert Helpers.string_matches_partial?("endend", items)
      assert Helpers.string_matches_partial?("endsend", items)
      assert Helpers.string_matches_partial?("endendendendend", items)
      assert Helpers.string_matches_partial?("rendsendlendbendtrend", items)
      refute Helpers.string_matches_partial?("Pendulum", items)

      {:ok, [r_partial_token(items: items)], ""} = ArtemisQL.decode("?at")

      assert Helpers.string_matches_partial?("Cat", items)
      assert Helpers.string_matches_partial?("bat", items)
      assert Helpers.string_matches_partial?("Dat", items)
      refute Helpers.string_matches_partial?("DAT", items)
    end

    test "can match more complicated partials" do
      {:ok, [r_partial_token(items: items)], ""} = ArtemisQL.decode("A?*end")

      assert Helpers.string_matches_partial?("Append", items)
      assert Helpers.string_matches_partial?("ABend", items)
      assert Helpers.string_matches_partial?("As we go to the end", items)
      assert Helpers.string_matches_partial?("All these ends, are just not the true end of the end", items)
      refute Helpers.string_matches_partial?("Aend", items)
    end
  end
end
