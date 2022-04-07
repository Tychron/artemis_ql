defmodule ArtemisQL.DecoderTest do
  use ExUnit.Case

  describe "decode/1" do
    test "can decode all value types" do
      assert {:ok, [{:word, "Word"}], ""} == ArtemisQL.decode("Word")
      assert {:ok, [{:word, "1"}], ""} == ArtemisQL.decode("1")
      assert {:ok, [{:word, "1"}], ".0"} == ArtemisQL.decode("1.0")
      assert {:ok, [{:word, "1-0"}], ""} == ArtemisQL.decode("1-0")
      assert {:ok, [{:word, "abc_def"}], ""} == ArtemisQL.decode("abc_def")
      assert {:ok, [{:quote, "1.0"}], ""} == ArtemisQL.decode("\"1.0\"")
      assert {:ok, [{:quote, "Quoted"}], ""} == ArtemisQL.decode("\"Quoted\"")
      assert {:ok, [{:quote, "quoted with spaces"}], ""} == ArtemisQL.decode("\"quoted with spaces\"")
      assert {:ok, [{:quote, "quoted with escaped\nvalue"}], ""} == ArtemisQL.decode("\"quoted with escaped\\nvalue\"")
      assert {:ok, [{:list, [{:word, "A"},{:word, "B"},{:word, "C"}]}], ""} == ArtemisQL.decode("A,B,C")
    end

    test "can parse a very long pair-list" do
      {:ok, list, ""} =
        ArtemisQL.decode(
          """
            host_number:14166284698,14166286231,15874303730,15874303731,15874303732,15874303733
            remote_number:17809534587,17809457114,15877784243,17809090049
            inserted_at:"2021-03-22".."2021-03-23T05:00:00.000000Z"
          """)

      assert [
        {:pair, {
          {:word, "host_number"},
          {:list, [
            {:word, "14166284698"},
            {:word, "14166286231"},
            {:word, "15874303730"},
            {:word, "15874303731"},
            {:word, "15874303732"},
            {:word, "15874303733"}
          ]}
        }},
        {:pair, {
          {:word, "remote_number"},
          {:list, [
            {:word, "17809534587"},
            {:word, "17809457114"},
            {:word, "15877784243"},
            {:word, "17809090049"}
          ]}
        }},
        {:pair, {
          {:word, "inserted_at"},
          {:range, {{:quote, "2021-03-22"}, {:quote, "2021-03-23T05:00:00.000000Z"}}}
        }}
      ] = list
    end

    test "can decode a word starting with special characters" do
      assert {:ok, [{:word, "@today"}], ""} == ArtemisQL.decode("@today")
      assert {:ok, [{:word, "@tomorrow"}], ""} == ArtemisQL.decode("@tomorrow")
      assert {:ok, [{:word, "@yesterday"}], ""} == ArtemisQL.decode("@yesterday")
      assert {:ok, [{:word, "@2-days-from-now"}], ""} == ArtemisQL.decode("@2-days-from-now")
    end

    test "can decode comparison operators with words" do
      assert {:ok, [{:cmp, {:eq, {:word, "Value"}}}], ""} == ArtemisQL.decode("=Value")
      assert {:ok, [{:cmp, {:neq, {:word, "Value"}}}], ""} == ArtemisQL.decode("!Value")
      assert {:ok, [{:cmp, {:gte, {:word, "Value"}}}], ""} == ArtemisQL.decode(">=Value")
      assert {:ok, [{:cmp, {:lte, {:word, "Value"}}}], ""} == ArtemisQL.decode("<=Value")
      assert {:ok, [{:cmp, {:gt, {:word, "Value"}}}], ""} == ArtemisQL.decode(">Value")
      assert {:ok, [{:cmp, {:lt, {:word, "Value"}}}], ""} == ArtemisQL.decode("<Value")
    end

    test "can decode comparison operators with groups" do
      group = {:group, [{:word, "Value"}]}
      assert {:ok, [{:cmp, {:eq, group}}], ""} == ArtemisQL.decode("=(Value)")
      assert {:ok, [{:cmp, {:neq, group}}], ""} == ArtemisQL.decode("!(Value)")
      assert {:ok, [{:cmp, {:gte, group}}], ""} == ArtemisQL.decode(">=(Value)")
      assert {:ok, [{:cmp, {:lte, group}}], ""} == ArtemisQL.decode("<=(Value)")
      assert {:ok, [{:cmp, {:gt, group}}], ""} == ArtemisQL.decode(">(Value)")
      assert {:ok, [{:cmp, {:lt, group}}], ""} == ArtemisQL.decode("<(Value)")

      group = {:group, [{:list, [{:word, "A"}, {:word, "B"}]}]}
      assert {:ok, [{:cmp, {:eq, group}}], ""} == ArtemisQL.decode("=(A,B)")
      assert {:ok, [{:cmp, {:neq, group}}], ""} == ArtemisQL.decode("!(A,B)")
      assert {:ok, [{:cmp, {:gte, group}}], ""} == ArtemisQL.decode(">=(A,B)")
      assert {:ok, [{:cmp, {:lte, group}}], ""} == ArtemisQL.decode("<=(A,B)")
      assert {:ok, [{:cmp, {:gt, group}}], ""} == ArtemisQL.decode(">(A,B)")
      assert {:ok, [{:cmp, {:lt, group}}], ""} == ArtemisQL.decode("<(A,B)")
    end

    test "can decode groups" do
      assert {:ok, [{:group, [{:word, "Value"}, {:word, "Other"}]}], ""} == ArtemisQL.decode("(Value Other)")
      assert {:ok, [
        {:group, [{:word, "Value"}, {:word, "Other"}]},
        {:group, [{:word, "Second"}, {:word, "Group"}]},
      ], ""} == ArtemisQL.decode("(Value Other) (Second Group)")
    end

    test "can parse a pair with a comparator value and partial date" do
      assert {:ok,
              [
                {:pair, {
                  {:word, "inserted_at"},
                  {:cmp, {:gte, {:word, "2019-01"}}}
                }}
              ], ""} == ArtemisQL.decode("inserted_at:>=2019-01")
    end

    test "can parse a pair with a comparator value and time" do
      assert {:ok,
              [
                {:pair, {
                  {:word, "inserted_at"},
                  {:cmp, {:lte, {:quote, "18:26:01"}}}
                }}
              ], ""} == ArtemisQL.decode("inserted_at:<=\"18:26:01\"")
    end

    test "can parse a quoted pair" do
      assert {:ok,
              [
                {:pair, {
                  {:quote, "inserted at"},
                  {:word, "placeholder"}
                }},
                {:pair, {
                  {:quote, "super duper"},
                  {:quote, "Worldo Molder"}
                }}
              ], ""} == ArtemisQL.decode("\"inserted at\":placeholder \"super duper\":\"Worldo Molder\"")
    end

    test "can parse a multi word query" do
      assert {:ok,
              [
                {:word, "a"},
                {:word, "b"},
                {:word, "c"},
                {:word, "d"},
                {:word, "e"},
              ], ""} == ArtemisQL.decode("a b c d e")
    end

    test "can parse a multi-pair query" do
      assert {:ok,
              [
                {:pair, {{:word, "a"}, {:word, "1"}}},
                {:pair, {{:word, "b"}, {:word, "2"}}},
                {:pair, {{:word, "c"}, {:word, "3"}}},
                {:pair, {{:word, "d"}, {:word, "4"}}},
                {:pair, {{:word, "e"}, {:word, "5"}}},
              ], ""} == ArtemisQL.decode("a:1 b:2 c:3 d:4 e:5")
    end

    test "can parse a reasonably complex query" do
      assert {:ok,
              [
                {:and, {
                        {:pair, {{:word, "inserted_at"},
                                 {:range, {{:word, "2020-01"}, :infinity}}}},
                        [{:pair, {{:word, "status"},
                                 {:word, "NEW"}}}]
                      }
                }
              ],
              ""} == ArtemisQL.decode("inserted_at:2020-01.. AND status:NEW")
    end

    test "can parse date ranges" do
      assert {:ok, [
        {:pair, {{:word, "inserted_at"}, {:range, {{:word, "2020-01-01"}, :infinity}}}}
      ], ""} == ArtemisQL.decode("inserted_at:2020-01-01..")
      assert {:ok, [
        {:pair, {{:word, "inserted_at"}, {:range, {:infinity, {:word, "2020-01-01"}}}}}
      ], ""} == ArtemisQL.decode("inserted_at:..2020-01-01")
      assert {:ok, [
        {:pair, {{:word, "inserted_at"}, {:range, {{:word, "2020-01-01"}, {:word, "2020-02-01"}}}}}
      ], ""} == ArtemisQL.decode("inserted_at:2020-01-01..2020-02-01")
    end

    test "can parse datetime ranges" do
      assert {:ok, [
        {:pair, {{:word, "inserted_at"}, {:range, {{:quote, "2020-01-01T23:20:32"}, :infinity}}}}
      ], ""} == ArtemisQL.decode("inserted_at:\"2020-01-01T23:20:32\"..")

      assert {:ok, [
        {:pair, {{:word, "inserted_at"}, {:range, {:infinity, {:quote, "2020-01-01T21:20:32"}}}}}
      ], ""} == ArtemisQL.decode("inserted_at:..\"2020-01-01T21:20:32\"")

      assert {:ok, [
        {:pair, {{:word, "inserted_at"}, {:range, {{:quote, "2020-01-01T18:20:32"}, {:quote, "2020-02-01T23:20:32"}}}}}
      ], ""} == ArtemisQL.decode("inserted_at:\"2020-01-01T18:20:32\"..\"2020-02-01T23:20:32\"")
    end
  end
end
