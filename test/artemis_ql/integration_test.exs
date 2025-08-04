defmodule ArtemisQL.IntegrationTest do
  use ArtemisQL.Support.ModelCase

  alias ArtemisQL.Support.TestModel

  @operators [">=", "<=", ">", "<", "=", "!", "~", "!~"]

  @all_nil_jmap %{
    "s" => nil,
    "i" => nil,
    "f" => nil,
    "d" => nil,
    "b" => nil,
    "o" => %{
      "s" => nil,
      "i" => nil,
      "f" => nil,
      "d" => nil,
      "b" => nil,
    }
  }

  @jmap_keys [
    "jmap_s",
    "jmap_i",
    "jmap_f",
    "jmap_d",
    "jmap_b",
    "jmap_o_s",
    "jmap_o_i",
    "jmap_o_f",
    "jmap_o_d",
    "jmap_o_b",
  ]

  @jmap_type_codes ["s", "i", "f", "d", "b"]

  describe "binary_id queries" do
    test "can query a record by its binary id" do
      model = insert_test_mode(name: "name1")

      assert [%{name: "name1"}] = execute_query("id:#{model.id}")
    end

    test "can query a list of ids" do
      model1 = insert_test_mode(name: "name1")
      model2 = insert_test_mode(name: "name2")

      assert [%{name: "name1"}, %{name: "name2"}] =
        execute_query("id:#{model1.id},#{model2.id}")
    end

    test "can query implicit null" do
      _model1 = insert_test_mode(name: "name1")
      _model2 = insert_test_mode(name: "name2")

      assert [] =
        execute_query("id: ")
    end
  end

  describe "integers queries" do
    test "can query a record by its binary id" do
      model = insert_test_mode(name: "name1", int: 12)

      assert [%{name: "name1"}] = execute_query("int:#{model.int}")
    end

    test "can query a list of integers" do
      model1 = insert_test_mode(name: "name1", int: 12)
      model2 = insert_test_mode(name: "name2", int: 13)

      assert [%{name: "name1"}, %{name: "name2"}] =
        execute_query("int:#{model1.int},#{model2.int}")
    end

    test "can query implicit null" do
      _model1 = insert_test_mode(name: "name1", int: nil)

      assert [%{name: "name1"}] =
        execute_query("int: ")
    end
  end

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

  describe "enum queries" do
    setup tags do
      _model1 = insert_test_mode(name: "name1", enum_i: :i_1)
      _model2 = insert_test_mode(name: "name2", enum_i: :i_2)
      _model3 = insert_test_mode(name: "name3", enum_i: :i_3)
      _model4 = insert_test_mode(name: "name4", enum_i: :i_4)

      _model5 = insert_test_mode(name: "name5", enum_i: :en_1)
      _model6 = insert_test_mode(name: "name6", enum_i: :en_2)
      _model7 = insert_test_mode(name: "name7", enum_i: :en_3)
      _model8 = insert_test_mode(name: "name8", enum_i: :en_4)

      {:ok, tags}
    end

    test "can lookup models by enum values" do
      assert [%{name: "name1"}] = execute_query("enum_i:i_1")
      assert [%{name: "name2"}] = execute_query("enum_i:i_2")
      assert [%{name: "name3"}] = execute_query("enum_i:i_3")
      assert [%{name: "name4"}] = execute_query("enum_i:i_4")
    end

    test "can lookup by a list of enum values" do
      assert [
        %{name: "name1"},
        %{name: "name2"},
        %{name: "name3"},
        %{name: "name4"},
      ] = execute_query("enum_i:i_1,i_2,i_3,i_4")
    end

    test "can lookup models by enum values with mixed" do
      assert [%{name: "name1"}] = execute_query("enum_i:i_1")
      assert [%{name: "name2"}] = execute_query("enum_i:i_2")
      assert [%{name: "name3"}] = execute_query("enum_i:i_3")
      assert [%{name: "name4"}] = execute_query("enum_i:i_4")
    end

    test "can lookup by an enum any char wildcard" do
      assert [
        %{name: "name1"},
        %{name: "name2"},
        %{name: "name3"},
        %{name: "name4"},
      ] = execute_query("enum_i:i_?")

      assert [
        %{name: "name1"},
        %{name: "name2"},
        %{name: "name3"},
        %{name: "name4"},
      ] = execute_query("enum_i:?_?")

      assert [
        %{name: "name5"},
        %{name: "name6"},
        %{name: "name7"},
        %{name: "name8"},
      ] = execute_query("enum_i:??_?")
    end

    test "can lookup by a splat wildcard" do
      assert [
        %{name: "name1"},
        %{name: "name5"},
      ] = execute_query("enum_i:*_1")
    end

    test "can lookup by a splat and any_char wildcard" do
      assert [
        %{name: "name1"},
        %{name: "name2"},
        %{name: "name3"},
        %{name: "name4"},
        %{name: "name5"},
        %{name: "name6"},
        %{name: "name7"},
        %{name: "name8"},
      ] = execute_query("enum_i:*_?")
    end
  end

  describe "jsonb queries" do
    test "can handle null on fields" do
      _model = insert_test_mode(name: "name", jmap: @all_nil_jmap)

      Enum.each(@jmap_keys, fn key ->
        assert [%{name: "name"}] = execute_query("#{key}:NULL")
      end)
    end

    test "can handle null on fields with logical operators" do
      _model = insert_test_mode(name: "name", jmap: @all_nil_jmap)

      Enum.each(@operators, fn op ->
        Enum.each(@jmap_keys, fn key ->
          query_string = "#{key}:#{op}NULL"
          case op do
            op when op in ["=", ">=", "<=", "~"] ->
              assert [%{name: "name"}] = execute_query(query_string)

            _ ->
              assert [] == execute_query(query_string)
          end
        end)
      end)
    end

    test "can handle values on fields with logical operators" do
      model = insert_test_mode(name: "name", jmap: random_jmap())

      Enum.each(@operators, fn op ->
        Enum.each(@jmap_type_codes, fn letter ->
          scalar_query_string = "jmap_#{letter}:#{op}#{model.jmap[letter]}"
          nested_query_string = "jmap_o_#{letter}:#{op}#{model.jmap["o"][letter]}"
          case op do
            op when op in ["=", ">=", "<=", "~"] ->
              assert [%{name: "name"}] = execute_query(scalar_query_string)
              assert [%{name: "name"}] = execute_query(nested_query_string)

            _ ->
              assert [] == execute_query(scalar_query_string)
              assert [] == execute_query(nested_query_string)
          end
        end)
      end)
    end

    test "can match on value" do
      model1 = insert_test_mode(name: "name1", jmap: random_jmap())

      Enum.each(@jmap_type_codes, fn letter ->
        scalar_query = "jmap_#{letter}:#{model1.jmap[letter]}"
        nested_scalar_query = "jmap_o_#{letter}:#{model1.jmap["o"][letter]}"
        assert [%{name: "name1"}] = execute_query(scalar_query)
        assert [%{name: "name1"}] = execute_query(nested_scalar_query)
      end)
    end

    # test "can handle pins" do
    #   jmap = random_jmap()
    #   jmap = Map.merge(jmap, jmap["o"])
    #   model1 = insert_test_mode(name: "name1", jmap: jmap)
    #   Enum.each(["s", "i", "f", "d", "b"], fn letter ->
    #     assert [%{name: "model1"}] = execute_query("jmap_#{letter}:^jmap_o_#{letter}")
    #   end)
    # end

    test "can handle lists" do
      model1 = insert_test_mode(name: "name1", jmap: random_jmap())
      model2 = insert_test_mode(name: "name2", jmap: random_jmap())

      Enum.each(@jmap_type_codes, fn letter ->
        scalar_query = "jmap_#{letter}:#{model1.jmap[letter]},#{model2.jmap[letter]}"
        nested_scalar_query = "jmap_o_#{letter}:#{model1.jmap["o"][letter]},#{model2.jmap["o"][letter]}"
        assert [%{name: "name1"}, %{name: "name2"}] = execute_query(scalar_query)
        assert [%{name: "name1"}, %{name: "name2"}] = execute_query(nested_scalar_query)
      end)
    end
  end

  describe "json array queries" do
    test "can handle null" do
      _model = insert_test_mode(name: "name", jarr: nil)
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

  def random_jmap do
    %{
      "s" => ArtemisQL.Random.random_base16_string(16),
      "i" => ArtemisQL.Random.random_integer(1000),
      "f" => ArtemisQL.Random.random_float(1000),
      "d" => ArtemisQL.Random.random_decimal(1000),
      "b" => ArtemisQL.Random.random_boolean(),
      "o" => %{
        "s" => ArtemisQL.Random.random_base16_string(16),
        "i" => ArtemisQL.Random.random_integer(1000),
        "f" => ArtemisQL.Random.random_float(1000),
        "d" => ArtemisQL.Random.random_decimal(1000),
        "b" => ArtemisQL.Random.random_boolean()
      }
    }
  end
end
