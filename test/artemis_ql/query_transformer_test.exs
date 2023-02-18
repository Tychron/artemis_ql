defmodule ArtemisQL.QueryTransformerTest do
  defmodule OtherSchema do
    use Ecto.Schema

    schema "other_schema" do
      timestamps(type: :utc_datetime_usec)

      field :name, :string

      field :other_field, :string
    end
  end

  defmodule QuerySchema do
    use Ecto.Schema

    schema "query_schema" do
      timestamps(type: :utc_datetime_usec)

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

    def_key_whitelist "id"
    def_key_whitelist "inserted_at"
    def_key_whitelist "updated_at"
    def_key_whitelist "name"
    def_key_whitelist "int"
    def_key_whitelist "flt"
    def_key_whitelist "dec"
    def_key_whitelist "bool"
    def_key_whitelist "time"
    def_key_whitelist "date"
    def_key_whitelist "naive"
    def_key_whitelist "jsonb_value"
    def_key_whitelist "jsonb_nested_value"
    def_key_whitelist "other_field"
    def_key_whitelist "other_name"

    def_pair_transform :id, {:type, :binary_id}
    def_pair_transform :inserted_at, {:type, :utc_datetime}
    def_pair_transform :updated_at, {:type, :utc_datetime}
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

  @search_map %ArtemisQL.SearchMap{
    key_whitelist: %{
      "id" => true,
      "inserted_at" => true,
      "updated_at" => true,
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
    test "can take a search list and query to produce a filtered query" do
      {:ok, list, ""} =
        ArtemisQL.decode("""
        inserted_at:\"2020-01-27T19:36:55Z\"
        updated_at:2020-01-27
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

      IO.inspect query

      assert %Ecto.Query{} = query
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
      test "fuzz field #{field_key} of type #{field_type}" do
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
      {:pair, {{:word, to_string(key)}, :NULL}}
    ]

    query =
      QuerySchema
      |> ArtemisQL.to_ecto_query(search_list, search_map)

    assert %Ecto.Query{} = query
  end

  defp fuzz_field_nullability_comparison(key, search_map) do
    for op <- [:eq, :neq, :lt, :lte, :gt, :gte] do
      search_list = [
        {
          :pair,
          {
            {:word, to_string(key)},
            {:cmp, {
              op,
              :NULL
            }}
          }
        }
      ]

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(search_list, search_map)

      assert %Ecto.Query{} = query
    end
  end

  defp fuzz_field_comparison(key, search_map) do
    for op <- [nil, :eq, :neq, :lt, :lte, :gt, :gte] do
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

    {:ok, search_list} = ArtemisQL.query_list_to_search_list([
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
