defmodule ArtemisQL.QueryTransformerTest do
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
    end
  end

  use ExUnit.Case

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
    },
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
        """)

      query =
        QuerySchema
        |> ArtemisQL.to_ecto_query(list, get_search_map(unquote(type)))

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
end

  defp get_search_map(:module) do
    TestSearchMap
  end

  defp get_search_map(:struct) do
    @search_map
  end
end
