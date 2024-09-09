defmodule ArtemisQL.DecoderTest do
  use ExUnit.Case

  @operators [
    {:eq, "="},
    {:neq, "!"},
    {:gte, ">="},
    {:lte, "<="},
    {:gt, ">"},
    {:lt, "<"},
    {:fuzz, "~"},
    {:nfuzz, "!~"},
  ]

  describe "decode/1" do
    test "can decode all value types" do
      assert {:ok, [{:word, "Word", _}], ""} = ArtemisQL.decode("Word")
      assert {:ok, [{:word, "1", _}], ""} = ArtemisQL.decode("1")
      assert {:ok, [{:word, "1", _}], ".0"} = ArtemisQL.decode("1.0")
      assert {:ok, [{:word, "1-0", _}], ""} = ArtemisQL.decode("1-0")
      assert {:ok, [{:word, "abc_def", _}], ""} = ArtemisQL.decode("abc_def")
      assert {:ok, [{:quote, "1.0", _}], ""} = ArtemisQL.decode("\"1.0\"")
      assert {:ok, [{:quote, "Quoted", _}], ""} = ArtemisQL.decode("\"Quoted\"")
      assert {:ok, [{:quote, "quoted with spaces", _}], ""} = ArtemisQL.decode("\"quoted with spaces\"")
      assert {:ok, [{:quote, "quoted with escaped\nvalue", _}], ""} = ArtemisQL.decode("\"quoted with escaped\\nvalue\"")
      assert {:ok,
        [
          {:list, [
            {:word, "A", _},
            {:word, "B", _},
            {:word, "C", _}
          ], _}
        ],
        ""
      } = ArtemisQL.decode("A,B,C")
    end

    test "can decode pin form" do
      assert {:ok, [
        {:pin, {:word, "Word", _}, _}
      ], ""} = ArtemisQL.decode("^Word")

      assert {:ok, [
        {:pin, {:quote, "Word", _}, _}
      ], ""} = ArtemisQL.decode("^\"Word\"")
    end

    test "can parse a very long pair-list" do
      {:ok, list, ""} =
        ArtemisQL.decode(
          """
          host_number:14166284698,14166286231,15874303730,15874303731,15874303732,15874303733
          remote_number:17809534587,17809457114,15877784243,17809090049
          inserted_at:"2021-03-22".."2021-03-23T05:00:00.000000Z"
          """
        )

      assert [
        {:pair, {
          {:word, "host_number", _},
          {:list, [
            {:word, "14166284698", _},
            {:word, "14166286231", _},
            {:word, "15874303730", _},
            {:word, "15874303731", _},
            {:word, "15874303732", _},
            {:word, "15874303733", _}
          ], _}
        }, _},
        {:pair, {
          {:word, "remote_number", _},
          {:list, [
            {:word, "17809534587", _},
            {:word, "17809457114", _},
            {:word, "15877784243", _},
            {:word, "17809090049", _}
          ], _}
        }, _},
        {:pair, {
          {:word, "inserted_at", _},
          {:range, {
            {:quote, "2021-03-22", _},
            {:quote, "2021-03-23T05:00:00.000000Z", _}
          }, _}
        }, _}
      ] = list
    end

    test "can parse quoted key pairs" do
      {:ok, list, ""} =
        ArtemisQL.decode(
          """
          "Hello, World":B
          "Goodbye, Universe":C
          "John Doe":"Sally Sue"
          """
        )

      assert [
        {:pair, {
          {:quote, "Hello, World", _},
          {:word, "B", _},
        }, _},
        {:pair, {
          {:quote, "Goodbye, Universe", _},
          {:word, "C", _},
        }, _},
        {:pair, {
          {:quote, "John Doe", _},
          {:quote, "Sally Sue", _},
        }, _},
      ] = list
    end

    test "can decode a word starting with special characters" do
      assert {:ok, [{:word, "@today", _}], ""} = ArtemisQL.decode("@today")
      assert {:ok, [{:word, "@tomorrow", _}], ""} = ArtemisQL.decode("@tomorrow")
      assert {:ok, [{:word, "@yesterday", _}], ""} = ArtemisQL.decode("@yesterday")
      assert {:ok, [{:word, "@2-days-from-now", _}], ""} = ArtemisQL.decode("@2-days-from-now")
    end

    test "can decode comparison operators with words" do
      Enum.each(@operators, fn {op_name, op} ->
        assert {:ok, [{:cmp, {^op_name, {:word, "Value", _}}, _}], ""} = ArtemisQL.decode("#{op}Value")
      end)
    end

    test "can decode comparison operators with groups of one value" do
      Enum.each(@operators, fn {op_name, op} ->
        assert {:ok, [
          {:cmp,
            {^op_name, {:group, [{:word, "Value", _}], _}},
          _}
        ], ""} = ArtemisQL.decode("#{op}(Value)")
      end)
    end

    test "can decode comparison operators with groups of multiple values" do
      Enum.each(@operators, fn {op_name, op} ->
        assert {:ok, [
          {:cmp,
            {^op_name,
              {:group, [
                {:list, [
                  {:word, "A", _},
                  {:word, "B", _}
                ], _}
              ], _}
            },
          _}
        ], ""} = ArtemisQL.decode("#{op}(A,B)")
      end)
    end

    test "can decode groups" do
      assert {:ok, [
        {:group, [
          {:word, "Value", _},
          {:word, "Other", _}
        ], _}
      ], ""} = ArtemisQL.decode("(Value Other)")

      assert {:ok, [
        {:group, [{:word, "Value", _}, {:word, "Other", _}], _},
        {:group, [{:word, "Second", _}, {:word, "Group", _}], _},
      ], ""} = ArtemisQL.decode("(Value Other) (Second Group)")
    end

    test "can parse an implicit nil pair terminated by end of sequence" do
      assert {:ok, [
        {:pair, {{:word, "inserted_at", _}, nil}, _}
      ], ""} = ArtemisQL.decode("inserted_at:")
    end

    test "can parse an implicit nil pair terminated by space" do
      assert {:ok, [
        {:pair, {{:word, "inserted_at", _}, nil}, _}
      ], ""} = ArtemisQL.decode("inserted_at: ")
    end

    test "can parse a pair with a comparator value and partial date" do
      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:cmp, {:gte, {:word, "2019-01", _}}, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:>=2019-01")
    end

    test "can parse a pair with a comparator value and time" do
      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:cmp, {:lte, {:quote, "18:26:01", _}}, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:<=\"18:26:01\"")
    end

    test "can parse a quoted pair" do
      assert {:ok, [
        {:pair, {
          {:quote, "inserted at", _},
          {:word, "placeholder", _}
        }, _},
        {:pair, {
          {:quote, "super duper", _},
          {:quote, "Worldo Molder", _}
        }, _}
      ], ""} = ArtemisQL.decode("\"inserted at\":placeholder \"super duper\":\"Worldo Molder\"")
    end

    test "can parse a multi word query" do
      assert {:ok, [
        {:word, "a", %{line_no: 1, col_no: 1}},
        {:word, "b", %{line_no: 1, col_no: 3}},
        {:word, "c", %{line_no: 1, col_no: 5}},
        {:word, "d", %{line_no: 1, col_no: 7}},
        {:word, "e", %{line_no: 1, col_no: 9}},
      ], ""} == ArtemisQL.decode("a b c d e")
    end

    test "can parse a multi-pair query" do
      assert {:ok, [
        {:pair, {{:word, "a", _}, {:word, "1", _}}, _},
        {:pair, {{:word, "b", _}, {:word, "2", _}}, _},
        {:pair, {{:word, "c", _}, {:word, "3", _}}, _},
        {:pair, {{:word, "d", _}, {:word, "4", _}}, _},
        {:pair, {{:word, "e", _}, {:word, "5", _}}, _},
      ], ""} = ArtemisQL.decode("a:1 b:2 c:3 d:4 e:5")
    end

    test "can parse a reasonably complex query" do
      assert {:ok, [
        {:and, {
          {:pair, {
            {:word, "inserted_at", _},
            {:range, {
              {:word, "2020-01", _},
              {:infinity, _, _}
            }, _}
          }, _},
          [
            {:pair, {
              {:word, "status", _},
              {:word, "NEW", _}
            }, _}
          ]
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:2020-01.. AND status:NEW")
    end

    test "can parse date ranges" do
      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:range, {
            {:word, "2020-01-01", _},
            {:infinity, _, _}
          }, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:2020-01-01..")

      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:range, {
            {:infinity, _, _},
            {:word, "2020-01-01", _}
          }, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:..2020-01-01")

      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:range, {
            {:word, "2020-01-01", _},
            {:word, "2020-02-01", _}
          }, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:2020-01-01..2020-02-01")
    end

    test "can parse datetime ranges" do
      # infinity range, useless but, it should work
      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:range, {
            {:infinity, _, _},
            {:infinity, _, _}
          }, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:..")

      # start date to infinity
      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:range, {
            {:quote, "2020-01-01T23:20:32", _},
            {:infinity, _, _},
          }, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:\"2020-01-01T23:20:32\"..")

      # infinty to end date
      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:range, {
            {:infinity, _, _},
            {:quote, "2020-01-01T21:20:32", _}
          }, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:..\"2020-01-01T21:20:32\"")

      # date to date
      assert {:ok, [
        {:pair, {
          {:word, "inserted_at", _},
          {:range, {
            {:quote, "2020-01-01T18:20:32", _},
            {:quote, "2020-02-01T23:20:32", _}
          }, _}
        }, _}
      ], ""} = ArtemisQL.decode("inserted_at:\"2020-01-01T18:20:32\"..\"2020-02-01T23:20:32\"")
    end
  end
end
