defmodule ArtemisQL.Support.TestAssertions do
  import ExUnit.Assertions

  def assert_search_list_without_meta(a, b) when is_list(a) and is_list(b) do
    assert ArtemisQL.Mapper.clear_all_token_meta(a) == ArtemisQL.Mapper.clear_all_token_meta(b)
  end
end
