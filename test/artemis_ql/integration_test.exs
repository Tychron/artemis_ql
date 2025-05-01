defmodule ArtemisQL.IntegrationTest do
  use ArtemisQL.Support.ModelCase

  alias ArtemisQL.Support.TestModel

  describe "string queries" do
    setup tags do
      _model1 = insert_test_mode(name: "name1")
      _model2 = insert_test_mode(name: "name2")
      _model3 = insert_test_mode(name: "name3")
      _model4 = insert_test_mode(name: "other_name3")

      {:ok, tags}
    end

    test "can query a scalar, with a scalar" do
      assert [%{name: "name1"}] = execute_query("name:name1")
      assert [%{name: "name2"}] = execute_query("name:name2")
      assert [%{name: "name3"}] = execute_query("name:name3")
    end

    test "can query a scalar, with a list of scalars" do
      assert [%{name: "name3"}] = execute_query("name:name3,name4,name5")
      assert [%{name: "name1"}, %{name: "name2"}, %{name: "name3"}, %{name: "other_name3"}] =
        execute_query("name:name*,other_name*")
    end
  end

  describe "json array queries" do
    test "can handle null" do
      model = insert_test_mode(name: "name", jarr: nil)
      assert [%{name: "name"}] = execute_query("jarr:NULL")
    end

    test "can query array of strings with a scalar" do
      _model1 = insert_test_mode(name: "name1", jarr: ["a", "b", "c"])
      _model2 = insert_test_mode(name: "name2", jarr: ["d", "e", "f"])
      assert [%{name: "name1"}] = execute_query("jarr:a")
    end

    test "can query array of strings with a list of scalars" do
      _model1 = insert_test_mode(name: "name1", jarr: ["a", "b", "c"])
      _model2 = insert_test_mode(name: "name2", jarr: ["d", "e", "f"])
      assert [%{name: "name1"}, %{name: "name2"}] = execute_query("jarr:a,d")
    end

    test "can query array of strings with a pattern" do
      _model1 = insert_test_mode(name: "name1", jarr: ["alpha", "bravo", "charlie"])
      _model2 = insert_test_mode(name: "name2", jarr: ["delta", "echo", "foxtrot"])
      assert [%{name: "name1"}] = execute_query("jarr:alp*")
    end

    test "can query array of strings with an array of patterns" do
      _model1 = insert_test_mode(name: "name1", jarr: ["alpha", "bravo", "charlie"])
      _model2 = insert_test_mode(name: "name2", jarr: ["delta", "echo", "foxtrot"])
      assert [%{name: "name1"}, %{name: "name2"}] = execute_query("jarr:bra*,*trot")
    end
  end

  def execute_query(query) do
    import Ecto.Query

    options = []
    ArtemisQL.to_ecto_query(TestModel, query, TestModel.search_spec(), options)
    |> order_by([s], s.name)
    |> ArtemisQL.Support.Repo.all()
  end
end
