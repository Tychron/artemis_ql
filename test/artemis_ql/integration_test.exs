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

    test "implicit empty value is rejected" do
      _model1 = insert_test_mode(name: "name1")
      _model2 = insert_test_mode(name: "name2")

      assert {:abort, {:empty_value, :id}} =
        ArtemisQL.to_ecto_query(TestModel, "id: ", TestModel.search_spec(), [])
    end
  end

  describe "malformed built-in type values" do
    test "return cast errors at every nesting level instead of raising" do
      malformed_values = [
        {"uuid", "not-a-uuid"},
        {"ulid", "not-a-ulid"},
        {"bool", "maybe"},
        {"int", "not-an-integer"},
        {"flt", "not-a-float"},
        {"dec", "not-a-decimal"},
        {"inet", "999.0.0.1"},
        {"cidr", "10.0.0.1"},
        {"date", "not-a-date"},
        {"time", "not-a-time"},
        {"uts", "not-a-datetime"},
        {"nts", "not-a-datetime"},
        {"narr_i", "not-an-integer"}
      ]

      for {field, value} <- malformed_values,
          search <- [
            "#{field}:#{value}",
            "#{field}:>#{value}",
            "#{field}:(#{value})",
            "#{field}:#{value},#{value}",
            "#{field}:#{value}..#{value}",
            "#{field}:#{value}*"
          ] do
        assert {:abort, :cast_error} =
                 ArtemisQL.to_ecto_query(TestModel, search, TestModel.search_spec(), []),
               "expected #{inspect(search)} to return a cast error"
      end
    end

    test "rejects malformed binary ids at every nesting level" do
      search_map = put_in(TestModel.search_spec().pair_transform.id, {:type, :binary_id})

      for search <- [
            "id:not-an-id",
            "id:>not-an-id",
            "id:(not-an-id)",
            "id:not-an-id,not-an-id",
            "id:not-an-id..not-an-id",
            "id:not-an-id*"
          ] do
        assert {:abort, :cast_error} =
                 ArtemisQL.to_ecto_query(TestModel, search, search_map, [])
      end
    end

    test "rejects values that do not match the Ecto schema type" do
      search_map = put_in(TestModel.search_spec().pair_transform.ulid, {:type, :binary_id})

      assert %Ecto.Query{} =
               ArtemisQL.to_ecto_query(
                 TestModel,
                 "ulid:#{Ecto.ULID.generate()}",
                 search_map,
                 []
               )

      for search <- [
            "ulid:#{Ecto.UUID.generate()}",
            "name:anything ulid:#{Ecto.UUID.generate()}"
          ] do
        assert {:abort, :cast_error} =
                 ArtemisQL.to_ecto_query(TestModel, search, search_map, [])
      end
    end

    test "unknown atoms return cast errors at every nesting level instead of raising" do
      search_map = put_in(TestModel.search_spec().pair_transform.str, {:type, :atom})
      unknown_atom = "artemis_ql_unknown_atom_#{System.unique_integer([:positive])}"

      for search <- [
            "str:#{unknown_atom}",
            "str:>#{unknown_atom}",
            "str:(#{unknown_atom})",
            "str:#{unknown_atom},#{unknown_atom}",
            "str:#{unknown_atom}..#{unknown_atom}",
            "str:#{unknown_atom}*"
          ] do
        assert {:abort, :cast_error} =
                 ArtemisQL.to_ecto_query(TestModel, search, search_map, [])
      end
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

    test "parses random integers in binary, octal and hex formats" do
      max_u32 = 4_294_967_296

      for _ <- 1..64 do
        value = ArtemisQL.Random.random_integer_between(0, max_u32)

        for formatted <- [
              "0b#{Integer.to_string(value, 2)}",
              "0o#{Integer.to_string(value, 8)}",
              "0x#{Integer.to_string(value, 16)}"
            ] do
          query =
            ArtemisQL.to_ecto_query(
              TestModel,
              "int:#{formatted}",
              TestModel.search_spec(),
              []
            )

          assert %Ecto.Query{} = query

          params =
            query.wheres
            |> Enum.flat_map(& &1.params)
            |> Enum.map(fn {value, _type} -> value end)

          assert [^value] = params
        end
      end
    end

    test "can query integer values with underscores" do
      _model1 = insert_test_mode(name: "name1", int: 1_234_567)

      assert [%{name: "name1"}] = execute_query("int:1_234_567")
    end

    test "rejects invalid underscore placement for integers" do
      for query <- ["int:_1234", "int:1234_", "int:0x_FF", "int:0b10_"] do
        assert {:abort, :cast_error} =
          ArtemisQL.to_ecto_query(TestModel, query, TestModel.search_spec(), [])
      end
    end

    test "implicit empty value is rejected" do
      _model1 = insert_test_mode(name: "name1", int: nil)

      assert {:abort, {:empty_value, :int}} =
        ArtemisQL.to_ecto_query(TestModel, "int: ", TestModel.search_spec(), [])
    end
  end

  describe "float queries" do
    test "can query exponent values with explicit plus signs" do
      _model1 = insert_test_mode(name: "name1", flt: 100.0)
      _model2 = insert_test_mode(name: "name2", flt: -100.0)

      assert [%{name: "name1"}] = execute_query("flt:1e+2")
      assert [%{name: "name2"}] = execute_query("flt:-1e+2")
    end

    test "can query float values with underscores" do
      _model1 = insert_test_mode(name: "name1", flt: 1_234.56)
      _model2 = insert_test_mode(name: "name2", flt: 125.0)

      assert [%{name: "name1"}] = execute_query("flt:1_234.5_6")
      assert [%{name: "name2"}] = execute_query("flt:1_2.5e+1")
    end

    test "rejects invalid underscore placement for floats" do
      for query <- ["flt:_1234.5", "flt:1234.5_", "flt:1._5", "flt:1_.5"] do
        assert {:abort, :cast_error} =
          ArtemisQL.to_ecto_query(TestModel, query, TestModel.search_spec(), [])
      end
    end
  end

  describe "decimal queries" do
    test "can query decimal values with underscores" do
      _model1 = insert_test_mode(name: "name1", dec: Decimal.new("1234.56"))
      _model2 = insert_test_mode(name: "name2", dec: Decimal.new("125"))

      assert [%{name: "name1"}] = execute_query("dec:1_234.5_6")
      assert [%{name: "name2"}] = execute_query("dec:1_2.5e+1")
    end

    test "rejects invalid underscore placement for decimals" do
      for query <- ["dec:_1234.5", "dec:1234.5_", "dec:1._5", "dec:1_.5"] do
        assert {:abort, :cast_error} =
          ArtemisQL.to_ecto_query(TestModel, query, TestModel.search_spec(), [])
      end
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

    test "invalid enum list values abort instead of raising" do
      assert {:abort, %ArtemisQL.Errors.InvalidEnumValue{key: :enum_i}} =
               ArtemisQL.to_ecto_query(
                 TestModel,
                 "enum_i:i_1,not_an_enum",
                 TestModel.search_spec(),
                 []
               )
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
    case ArtemisQL.to_ecto_query(TestModel, query, TestModel.search_spec(), options) do
      {:abort, _} ->
        flunk "invalid query: #{query}"

      query ->
        query
        |> order_by([s], s.name)
        |> ArtemisQL.Support.Repo.all()
    end
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
