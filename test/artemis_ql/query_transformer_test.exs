defmodule ArtemisQL.QueryTransformerTest do
  defmodule OtherSchema do
    use Ecto.Schema

    schema "other_schema" do
      timestamps(type: :utc_datetime_usec)

      field :expired_at, :utc_datetime_usec

      field :name, :string

      field :other_field, :string
    end
  end

  defmodule QuerySchema do
    use Ecto.Schema

    schema "query_schema" do
      timestamps(type: :utc_datetime_usec)

      field :expired_at, :utc_datetime_usec

      field :name, :string
      field :int, :integer
      field :flt, :float
      field :dec, :decimal
      field :bool, :boolean

      field :time, :time
      field :date, :date
      field :naive, :naive_datetime

      field :jsonb, :map

      belongs_to :other, OtherSchema
    end
  end

  use ExUnit.Case, async: true

  defmodule TestSearchMap do
    use ArtemisQL.SearchMap

    def_allowed_key "id"
    def_allowed_key "inserted_at"
    def_allowed_key "updated_at"
    def_allowed_key "expired_at"
    def_allowed_key "name"
    def_allowed_key "int"
    def_allowed_key "flt"
    def_allowed_key "dec"
    def_allowed_key "bool"
    def_allowed_key "time"
    def_allowed_key "date"
    def_allowed_key "naive"
    def_allowed_key "jsonb_value"
    def_allowed_key "jsonb_nested_value"
    def_allowed_key "other_field"
    def_allowed_key "other_name"

    def_pair_transform :id, {:type, :binary_id}
    def_pair_transform :inserted_at, {:type, :utc_datetime}
    def_pair_transform :updated_at, {:type, :utc_datetime}
    def_pair_transform :expired_at, {:type, :utc_datetime}
    def_pair_transform :name, {:type, :string}
    def_pair_transform :int, {:type, :integer}
    def_pair_transform :flt, {:type, :float}
    def_pair_transform :dec, {:type, :decimal}
    def_pair_transform :bool, {:type, :boolean}
    def_pair_transform :time, {:type, :time}
    def_pair_transform :date, {:type, :date}
    def_pair_transform :naive, {:type, :naive_datetime}
    def_pair_transform :jsonb_value, {:type, :string}
    def_pair_transform :jsonb_nested_value, {:type, :string}
    def_pair_transform :other_field, {:type, :string}
    def_pair_transform :other_name, {:type, :string}

    def_pair_filter :id, {:type, :string}
    def_pair_filter :inserted_at, {:type, :utc_datetime}
    def_pair_filter :updated_at, {:type, :utc_datetime}
    def_pair_filter :expired_at, {:type, :utc_datetime}
    def_pair_filter :name, {:type, :string}
    def_pair_filter :int, {:type, :integer}
    def_pair_filter :flt, {:type, :float}
    def_pair_filter :dec, {:type, :decimal}
    def_pair_filter :bool, {:type, :boolean}
    def_pair_filter :time, {:type, :time}
    def_pair_filter :date, {:type, :date}
    def_pair_filter :naive, {:type, :naive_datetime}
    def_pair_filter :jsonb_value, {:jsonb, :string, :data, ["value"]}
    def_pair_filter :jsonb_nested_value, {:jsonb, :string, :data, ["nested", "value"]}
    def_pair_filter :other_field, {:assoc, :string, :other}
    def_pair_filter :other_name, {:assoc, :string, :other, :name}

    @impl true
    def before_filter(query, key, _value, assigns) when key in [:other_field, :other_name] do
      import Ecto.Query

      if assigns[:joined_other] do
        {query, assigns}
      else
        query =
          query
          |> join(:inner, [m], other in assoc(m, :other), as: :other)

        {query, Map.put(assigns, :joined_other, true)}
      end
    end

    @impl true
    def before_filter(query, _key, _value, assigns) do
      {query, assigns}
    end
  end

  import ArtemisQL.Tokens

  alias ArtemisQL.Errors.KeyNotFound

  @search_map %ArtemisQL.SearchMap{
    allowed_keys: %{
      "id" => true,
      "inserted_at" => true,
      "updated_at" => true,
      "expired_at" => true,
      "name" => true,
      "int" => true,
      "flt" => true,
      "dec" => true,
      "bool" => true,
      "time" => true,
      "date" => true,
      "naive" => true,
      "jsonb_value" => true,
      "jsonb_nested_value" => true,
      "other_field" => true,
      "other_name" => true,
    },
    pair_transform: %{
      id: {:type, :binary_id},
      inserted_at: {:type, :utc_datetime},
      updated_at: {:type, :utc_datetime},
      expired_at: {:type, :utc_datetime},
      name: {:type, :string},
      int: {:type, :integer},
      flt: {:type, :float},
      dec: {:type, :decimal},
      bool: {:type, :boolean},
      time: {:type, :time},
      date: {:type, :date},
      naive: {:type, :naive_datetime},
      jsonb_value: {:type, :string},
      jsonb_nested_value: {:type, :string},
      other_field: {:type, :string},
      other_name: {:type, :string},
    },
    before_filter: &TestSearchMap.before_filter/4,
    pair_filter: %{
      id: {:type, :string},
      inserted_at: {:type, :utc_datetime},
      updated_at: {:type, :utc_datetime},
      expired_at: {:type, :utc_datetime},
      name: {:type, :string},
      int: {:type, :integer},
      flt: {:type, :float},
      dec: {:type, :decimal},
      bool: {:type, :boolean},
      time: {:type, :time},
      date: {:type, :date},
      naive: {:type, :naive_datetime},
      jsonb_value: {:jsonb, :string, :jsonb, ["value"]},
      jsonb_nested_value: {:jsonb, :string, :jsonb, ["nested", "value"]},
      other_field: {:assoc, :string, :other},
      other_name: {:assoc, :string, :other, :name},
    },
    resolver: nil
  }

for type <- [:struct, :module] do
  describe "(#{type}) to_ecto_query/3" do
    test "can gracefully handle missing keys" do
      assert {:ok, list, ""} =
        ArtemisQL.decode("""
        not_found:WHOOP
        """)

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert {:abort, %KeyNotFound{key: "not_found"}} = query
    end

    test "can take a search list and query to produce a filtered query" do
      assert {:ok, list, ""} =
        ArtemisQL.decode("""
        inserted_at:\"2020-01-27T19:36:55Z\"
        updated_at:2020-01-27
        expired_at:>^inserted_at
        name:Aname
        int:23
        flt:\"23.0\"
        dec:\"366.3764\"
        bool:false
        date:2020
        naive:2020-01-27
        jsonb_value:Something
        jsonb_nested_value:SomethingElse
        other_field:Something2
        other_name:Something3
        """)

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "can handle AND chains without crashing" do
      assert {:ok, list, ""} = ArtemisQL.decode("name:Aname AND int:23")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "returns abort for OR expressions" do
      assert {:ok, list, ""} = ArtemisQL.decode("name:Aname OR int:23")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert {:abort, :unsupported_logical_or} = query
    end

    test "returns abort for NOT expressions" do
      assert {:ok, list, ""} = ArtemisQL.decode("NOT name:Aname")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert {:abort, :unsupported_logical_not} = query
    end

    test "returns abort for type cast failures" do
      assert {:ok, list, ""} = ArtemisQL.decode("int:abc")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert {:abort, :cast_error} = query
    end

    test "expands @now for utc_datetime into full-day range filters" do
      assert {:ok, list, ""} = ArtemisQL.decode("inserted_at:@now")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query

      datetimes =
        query.wheres
        |> Enum.flat_map(& &1.params)
        |> Enum.map(fn {value, _type} -> value end)
        |> Enum.filter(&match?(%DateTime{}, &1))

      assert 2 == length(datetimes)

      [a, b] = Enum.sort_by(datetimes, &DateTime.to_unix(&1, :microsecond))

      assert {0, 0, 0} == {a.hour, a.minute, a.second}
      assert {23, 59, 59} == {b.hour, b.minute, b.second}
      assert DateTime.to_date(a) == DateTime.to_date(b)
    end

    test "supports @last-24-hours as a utc_datetime range start" do
      assert {:ok, list, ""} = ArtemisQL.decode("inserted_at:@last-24-hours..")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query

      datetimes =
        query.wheres
        |> Enum.flat_map(& &1.params)
        |> Enum.map(fn {value, _type} -> value end)
        |> Enum.filter(&match?(%DateTime{}, &1))

      assert [range_start] = datetimes

      expected_start = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)
      drift_seconds = abs(DateTime.diff(range_start, expected_start, :second))

      assert drift_seconds <= 2
    end

    test "can handle wildcards for strings" do
      {:ok, list, ""} = ArtemisQL.decode("name:Name*")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "can handle any_char for strings" do
      {:ok, list, ""} = ArtemisQL.decode("name:?ame?")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "can handle wildcards for integers" do
      {:ok, list, ""} = ArtemisQL.decode("int:345*")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "can handle ranges for integers" do
      {:ok, list, ""} = ArtemisQL.decode("int:22..165")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "grouped integer single value works" do
      {:ok, list, ""} = ArtemisQL.decode("int:(1)")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "deeply nested grouped integer single value works" do
      {:ok, list, ""} = ArtemisQL.decode("int:((((1))))")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "grouped integer list works" do
      {:ok, list, ""} = ArtemisQL.decode("int:(1,2)")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "deeply nested grouped integer list works" do
      {:ok, list, ""} = ArtemisQL.decode("int:((((1,2))))")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "comparison with grouped integer list works" do
      {:ok, list, ""} = ArtemisQL.decode("int:=(1,2)")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "comparison lists for integers work" do
      {:ok, list, ""} = ArtemisQL.decode("int:>1,=2,<3")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "grouped comparison lists for integers work" do
      {:ok, list, ""} = ArtemisQL.decode("int:(>1,=2,<3)")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "comparison with deeply nested grouped integer list works" do
      {:ok, list, ""} = ArtemisQL.decode("int:=((((1,2))))")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "mixed-arity nested grouped integer is flattened and works" do
      {:ok, list, ""} = ArtemisQL.decode("int:(1,(2,(3,4)))")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "comparison mixed-arity nested grouped integer is flattened and works" do
      {:ok, list, ""} = ArtemisQL.decode("int:=(1,(2,(3,4)))")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "empty grouped integer aborts" do
      {:ok, list, ""} = ArtemisQL.decode("int:()")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert {:abort, {:empty_group, :int}} = query
    end

    test "wildcard-only grouped integer is ignored" do
      {:ok, list, ""} = ArtemisQL.decode("int:(*)")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert QuerySchema == query
    end

    test "any-char-only grouped integer becomes single-character match" do
      {:ok, list, ""} = ArtemisQL.decode("int:(?)")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
      assert 1 == length(query.wheres)

      patterns =
        query.wheres
        |> Enum.flat_map(& &1.params)
        |> Enum.map(fn {value, _type} -> value end)
        |> Enum.filter(&is_binary/1)

      assert ["_"] == patterns
    end

    test "space-separated grouped integers abort" do
      {:ok, list, ""} = ArtemisQL.decode("int:(1 2)")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert {:abort, %ArtemisQL.Errors.UnsupportedSearchTermForField{key: :int}} = query
    end

    test "range-only grouped integer aborts" do
      {:ok, list, ""} = ArtemisQL.decode("int:(1..2)")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert {:abort, %ArtemisQL.Errors.UnsupportedSearchTermForField{key: :int}} = query
    end

    test "empty value after key aborts" do
      {:ok, list, ""} = ArtemisQL.decode("int: ")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert {:abort, {:empty_value, :int}} = query
    end

    test "time ranges are handled" do
      {:ok, list, ""} = ArtemisQL.decode("time:\"04:00:00\"..\"09:43:27\"")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "date ranges are handled" do
      {:ok, list, ""} = ArtemisQL.decode("date:\"2020-01-27\"..\"2020-01-27\"")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "utc_datetime ranges are handled" do
      {:ok, list, ""} = ArtemisQL.decode("inserted_at:\"2020-01-27T10:00:00Z\"..\"2020-01-27T20:00:00Z\"")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end

    test "naive_datetime ranges are handled" do
      {:ok, list, ""} = ArtemisQL.decode("naive:\"2020-01-27T10:00:00Z\"..\"2020-01-27T20:00:00Z\"")

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

      assert %Ecto.Query{} = query
    end
  end

  describe "(#{type}) field type fuzzing" do
    for {field_key, {:type, field_type}} <- @search_map.pair_transform do
      test "fuzz field `#{field_key}` of type `#{field_type}`" do
        fuzz_field(unquote(field_key), get_search_map(unquote(type)))
      end
    end
  end
end

  defp get_search_map(:module) do
    TestSearchMap
  end

  defp get_search_map(:struct) do
    @search_map
  end

  defp fuzz_field(key, search_map) do
    fuzz_field_nullability(key, search_map)
    fuzz_field_nullability_comparison(key, search_map)
    fuzz_field_comparison(key, search_map)
    fuzz_field_partial(key, search_map)
  end

  defp fuzz_field_nullability(key, search_map) do
    search_list = [
      {:pair, {r_word_token(value: to_string(key)), r_null_token()}, nil}
    ]

    query =
      QuerySchema
      |> ArtemisQL.to_ecto_query(search_list, search_map)

    assert %Ecto.Query{} = query
  end

  defp fuzz_field_nullability_comparison(key, search_map) do
    for op <- [:eq, :neq, :lt, :lte, :gt, :gte, :fuzz, :nfuzz] do
      search_list = [
        {
          :pair,
          {
            r_word_token(value: to_string(key)),
            r_cmp_token(pair: {op, r_null_token()}),
          },
          nil
        }
      ]

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(search_list, search_map)

      assert %Ecto.Query{} = query
    end
  end

  defp fuzz_field_comparison(key, search_map) do
    for op <- [nil, :eq, :neq, :lt, :lte, :gt, :gte, :fuzz, :nfuzz] do
      {:type, type} = @search_map.pair_transform[key]
      {:ok, value} = ArtemisQL.Encoder.encode_value(ArtemisQL.Random.random_value_of_type(type))

      {:ok, search_list} = ArtemisQL.query_list_to_search_list([
        %{
          key: to_string(key),
          op: op,
          value: value
        }
      ])

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(search_list, search_map)

      assert %Ecto.Query{} = query
    end
  end

  defp fuzz_field_partial(key, search_map) do
    {:type, type} = @search_map.pair_transform[key]

    {:ok, value} =
      ArtemisQL.Encoder.encode_value(case type do
        :date ->
          ArtemisQL.Random.random_partial_date()

        :time ->
          ArtemisQL.Random.random_partial_time()

        :utc_datetime ->
          ArtemisQL.Random.random_partial_datetime()

        :naive_datetime ->
          ArtemisQL.Random.random_partial_naive_datetime()

        :string ->
          ArtemisQL.Random.random_wildcard_partial(100)

        scalar when scalar in [:boolean, :integer, :float, :decimal, :binary_id] ->
          ArtemisQL.Random.random_value_of_type(type)
      end)

    assert {:ok, search_list} =
      ArtemisQL.query_list_to_search_list([
        %{
          key: to_string(key),
          value: case type do
            :string ->
              %{
                :"$partial" => value,
              }

            _ ->
              value
          end
        }
      ])

    query =
      QuerySchema
      |> ArtemisQL.to_ecto_query(search_list, search_map)

    assert %Ecto.Query{} = query
  end
end

defmodule ArtemisQL.NetworkTypesQueryTransformerTest do
  use ExUnit.Case, async: true

  defmodule NetworkSchema do
    use Ecto.Schema

    schema "network_schema" do
      field :ip, :string
      field :network, :string
    end
  end

  @search_map %ArtemisQL.SearchMap{
    allowed_keys: %{
      "ip" => true,
      "network" => true,
    },
    pair_transform: %{
      ip: {:type, :inet},
      network: {:type, :cidr},
    },
    pair_filter: %{
      ip: {:type, :inet},
      network: {:type, :cidr},
    },
    resolver: nil
  }

  test "inet supports eq and mapped fuzz operations" do
    for query <- ["ip:192.168.1.1", "ip:~192.168.1.1", "ip:!~192.168.1.1"] do
      {:ok, list, ""} = ArtemisQL.decode(query)
      result = ArtemisQL.to_ecto_query(NetworkSchema, list, @search_map)
      assert %Ecto.Query{} = result
    end
  end

  test "inet supports ordering comparisons" do
    for query <- ["ip:>192.168.1.1", "ip:>=192.168.1.1", "ip:<192.168.1.1", "ip:<=192.168.1.1"] do
      {:ok, list, ""} = ArtemisQL.decode(query)
      result = ArtemisQL.to_ecto_query(NetworkSchema, list, @search_map)
      assert %Ecto.Query{} = result
    end
  end

  test "cidr values are accepted" do
    {:ok, list, ""} = ArtemisQL.decode("network:10.0.0.0/8")
    result = ArtemisQL.to_ecto_query(NetworkSchema, list, @search_map)
    assert %Ecto.Query{} = result
  end

  test "inet grouped values are accepted" do
    {:ok, list, ""} = ArtemisQL.decode("ip:(192.168.1.1,10.0.0.1)")
    result = ArtemisQL.to_ecto_query(NetworkSchema, list, @search_map)
    assert %Ecto.Query{} = result
  end

  test "inet grouped comparator values are accepted" do
    {:ok, list, ""} = ArtemisQL.decode("ip:(>1.1.1.1,=2.2.2.2,<3.3.3.3)")
    result = ArtemisQL.to_ecto_query(NetworkSchema, list, @search_map)
    assert %Ecto.Query{} = result
  end

  test "cidr grouped values are accepted" do
    {:ok, list, ""} = ArtemisQL.decode("network:(10.0.0.0/8,192.168.0.0/16)")
    result = ArtemisQL.to_ecto_query(NetworkSchema, list, @search_map)
    assert %Ecto.Query{} = result
  end

  test "invalid inet/cidr values abort with cast errors" do
    for {query, reason} <- [
      {"ip:999.0.0.1", :cast_error},
      {"network:10.0.0.1", :cast_error},
      {"network:10.0.0.0/40", :cast_error},
    ] do
      {:ok, list, ""} = ArtemisQL.decode(query)
      assert {:abort, ^reason} = ArtemisQL.to_ecto_query(NetworkSchema, list, @search_map)
    end
  end
end
