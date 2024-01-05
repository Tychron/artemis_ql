defmodule ArtemisQL.TokenizerTest do
  use ExUnit.Case

  alias ArtemisQL.Tokenizer

  describe "tokenize/2" do
    test "can tokenize operators" do
      assert {:ok, {:cmp_op, :eq, %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 2}, ""} == Tokenizer.tokenize("=")
      assert {:ok, {:cmp_op, :neq, %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 2}, ""} == Tokenizer.tokenize("!")
      assert {:ok, {:cmp_op, :gte, %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 3}, ""} == Tokenizer.tokenize(">=")
      assert {:ok, {:cmp_op, :lte, %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 3}, ""} == Tokenizer.tokenize("<=")
      assert {:ok, {:cmp_op, :lt, %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 2}, ""} == Tokenizer.tokenize("<")
      assert {:ok, {:cmp_op, :gt, %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 2}, ""} == Tokenizer.tokenize(">")
      assert {:ok, {:cmp_op, :fuzz, %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 2}, ""} == Tokenizer.tokenize("~")
      assert {:ok, {:cmp_op, :nfuzz, %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 3}, ""} == Tokenizer.tokenize("!~")
    end

    test "can tokenize a word with leading special characters" do
      assert {:ok, {:word, "@Word", %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 6}, ""} == Tokenizer.tokenize("@Word")
    end

    test "can tokenize group parts" do
      assert {:ok, {:group, [], %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 3}, ""} == Tokenizer.tokenize("()")
    end

    test "can tokenize unicode sequence \\u{H*}" do
      assert {:ok, {:quote, "ド", %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 11}, "\n"} == Tokenizer.tokenize("""
      "\\u{30C9}"
      """)
    end

    test "can tokenize unicode sequence \\uHHHH" do
      assert {:ok, {:quote, "ド", %{line_no: 1, col_no: 1}}, %{line_no: 1, col_no: 9}, "\n"} == Tokenizer.tokenize("""
      "\\u30C9"
      """)
    end
  end

  describe "tokenize_all/1" do
    test "can tokenize a simple query" do
      assert {:ok, [
        {:word, "keyword", _},
        {:space, _, _},
        {:word, "key", _},
        {:pair_op, nil, _},
        {:word, "value", _},
      ], %{line_no: 1, col_no: 18}, ""} = Tokenizer.tokenize_all("keyword key:value")
    end

    test "can tokenize infinite ranges" do
      assert {:ok, [
        {:word, "a", %{line_no: 1, col_no: 1}},
        {:pair_op, nil, %{line_no: 1, col_no: 2}},
        {:range_op, nil, %{line_no: 1, col_no: 3}},
      ], %{line_no: 1, col_no: 5}, ""} == Tokenizer.tokenize_all("a:..")

      assert {:ok, [
        {:word, "a", %{line_no: 1, col_no: 1}},
        {:pair_op, nil, %{line_no: 1, col_no: 2}},
        {:word, "x", %{line_no: 1, col_no: 3}},
        {:range_op, nil, %{line_no: 1, col_no: 4}},
      ], %{line_no: 1, col_no: 6}, ""} == Tokenizer.tokenize_all("a:x..")

      assert {:ok, [
        {:word, "a", %{line_no: 1, col_no: 1}},
        {:pair_op, nil, %{line_no: 1, col_no: 2}},
        {:range_op, nil, %{line_no: 1, col_no: 3}},
        {:word, "y", %{line_no: 1, col_no: 5}},
      ], %{line_no: 1, col_no: 6}, ""} == Tokenizer.tokenize_all("a:..y")
    end
  end
end
