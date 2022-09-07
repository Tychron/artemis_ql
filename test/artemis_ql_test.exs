defmodule ArtemisQLTest do
  use ExUnit.Case

  describe "string -> search list -> query list -> search list -> string" do
    test "can perform full on empty query" do
      assert encoding_cycle("")
    end

    test "can perform full encode/decode cycle" do
      assert encoding_cycle("a:2")
      assert encoding_cycle("Term key:value key2:0 \"quoted key\":\"quoted value\"")
    end
  end

  def encoding_cycle(str) when is_binary(str) do
    {:ok, search_list, ""} = ArtemisQL.decode(str)

    {:ok, query_list} = ArtemisQL.search_list_to_query_list(search_list)

    {:ok, search_list2} = ArtemisQL.query_list_to_search_list(query_list)

    assert search_list == search_list2

    {:ok, str2} = ArtemisQL.encode(search_list2)

    assert str == str2
  end
end
