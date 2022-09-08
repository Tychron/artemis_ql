defmodule ArtemisQL.TokenizerTest do
  use ExUnit.Case

  alias ArtemisQL.Tokenizer

  describe "tokenize/2" do
    test "can tokenize a word with leading special characters" do
      assert {:ok, {:word, "@Word"}, ""} == Tokenizer.tokenize("@Word")
    end
  end

  describe "tokenize_all/1" do
    test "can tokenize an infinite range" do
      assert {:ok, [{:word, "a"}, :pair_op, :range_op], ""} == Tokenizer.tokenize_all("a:..")
    end
  end
end
