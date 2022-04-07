defmodule ArtemisQL.TokenizerTest do
  use ExUnit.Case

  alias ArtemisQL.Tokenizer

  describe "tokenize/2" do
    test "can tokenize a word with leading special characters" do
      assert {:ok, {:word, "@Word"}, ""} == Tokenizer.tokenize("@Word")
    end
  end
end
