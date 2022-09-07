defmodule ArtemisQL.MapperTest do
  use ExUnit.Case

  describe "search_list_to_query_list/2" do
    test "can decode a query list" do
      assert {:ok, search_list, ""} =
        ArtemisQL.decode("""
        Term
        a:2
        "c":"d"
        >=2
        e:<=2022-09-07
        f:AB*Y?Z
        g:"H*llo, "*"Wo?ld"
        h:1,2,3
        i:"Hello, World","What can I do?","But eat frogs."
        """)

      assert {:ok, query_list} =
        ArtemisQL.search_list_to_query_list(search_list)

      assert [
        %{
          value: "Term"
        },
        %{
          key: "a",
          value: "2",
        },
        %{
          key: "c",
          value: "d",
        },
        %{
          op: :gte,
          value: "2",
        },
        %{
          key: "e",
          op: :lte,
          value: "2022-09-07",
        },
        %{
          key: "f",
          value: %{
            :"$partial" => [
              "AB",
              %{:"$wildcard" => true},
              "Y",
              %{:"$any_char" => true},
              "Z",
            ],
          },
        },
        %{
          key: "g",
          value: %{
            :"$partial" => [
              "H*llo, ",
              %{:"$wildcard" => true},
              "Wo?ld",
            ],
          },
        },
        %{
          key: "h",
          value: ["1", "2", "3"],
        },
        %{
          key: "i",
          value: ["Hello, World", "What can I do?", "But eat frogs."],
        },
      ] == query_list
    end
  end

  describe "query_list_to_search_list/2" do
  end
end
