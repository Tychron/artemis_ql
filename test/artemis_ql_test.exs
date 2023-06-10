defmodule ArtemisQLTest do
  use ExUnit.Case

  import ArtemisQL.Support.TestAssertions

  describe "string -> search list -> query list -> search list -> string" do
    test "can perform full on empty query" do
      assert encoding_cycle("")
    end

    test "can perform full encode/decode cycle" do
      assert encoding_cycle("a:2")
      assert encoding_cycle(
        "Term key:value key2:0 \"quoted key\":\"quoted value\" list:1,2,3 list_q:\"Hello World\",\"Goodbye Universe\""
      )
      assert encoding_cycle(
        ".. a:x..y b:x.. c:..y d:.."
      )
      assert encoding_cycle(
        "* a:* b:? c:Abc* d:*Xyz e:Abc? f:?Xyz g:*Abc* h:?Xyz?"
      )
      assert encoding_cycle(
        "a:=2 b:!3 c:>=4 d:>5 e:<=6 f:<7"
      )
    end
  end

  def encoding_cycle(str) when is_binary(str) do
    {:ok, search_list, ""} = ArtemisQL.decode(str)

    {:ok, query_list} = ArtemisQL.search_list_to_query_list(search_list)

    {:ok, search_list2} = ArtemisQL.query_list_to_search_list(query_list)

    assert_search_list_without_meta(search_list, search_list2)

    {:ok, str2} = ArtemisQL.encode(search_list2)

    assert str == str2
  end
end
