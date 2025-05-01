defmodule ArtemisQL.Support.TestModel do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "test_models" do
    field :serial_id, :integer

    timestamps()

    field :name, :string
    field :notes, :string

    field :int, :integer
    field :dec, :decimal
    field :flt, :float
    field :str, :string
    field :jarr, {:array, :string}
    field :jmap, :map
    field :narr_s, {:array, :string}
    field :narr_i, {:array, :integer}
    field :bool, :boolean
    field :time, :time
    field :date, :date
    field :uts, :utc_datetime_usec
    field :nts, :naive_datetime_usec
    field :uuid, Ecto.UUID
    field :ulid, Ecto.ULID

    belongs_to :other_model, __MODULE__
  end

  def search_spec do
    %ArtemisQL.SearchMap{
      allowed_keys: %{
        "id" => true,
        "serial_id" => true,
        "inserted_at" => true,
        "updated_at" => true,
        "name" => true,
        "notes" => true,
        "int" => true,
        "dec" => true,
        "flt" => true,
        "str" => true,
        "jarr" => true,
        "jmap" => true,
        "narr_i" => true,
        "narr_s" => true,
        "bool" => true,
        "time" => true,
        "date" => true,
        "uts" => true,
        "nts" => true,
        "uuid" => true,
        "ulid" => true,
        "other_model_id" => true,
      },
      pair_transform: %{
        id: {:type, :uuid},
        serial_id: {:type, :integer},
        inserted_at: {:type, :utc_datetime},
        updated_at: {:type, :utc_datetime},
        name: {:type, :string},
        notes: {:type, :string},
        int: {:type, :integer},
        dec: {:type, :decimal},
        flt: {:type, :float},
        str: {:type, :string},
        jarr: {:type, {:json_array, :string}},
        jmap: {:type, :map},
        narr_s: {:type, {:array, :string}},
        narr_i: {:type, {:array, :integer}},
        bool: {:type, :boolean},
        time: {:type, :time},
        date: {:type, :date},
        uts: {:type, :utc_datetime},
        nts: {:type, :naive_datetime},
        uuid: {:type, :uuid},
        ulid: {:type, :ulid},
        other_model_id: {:type, :uuid},
      },
      pair_filter: %{
        id: {:type, :atom},
        serial_id: {:type, :integer},
        inserted_at: {:type, :utc_datetime},
        updated_at: {:type, :utc_datetime},
        name: {:type, :string},
        notes: {:type, :string},
        int: {:type, :integer},
        dec: {:type, :decimal},
        flt: {:type, :float},
        str: {:type, :string},
        jarr: {:type, {:json_array, :string}},
        jmap: {:type, :map},
        narr_s: {:type, {:array, :string}},
        narr_i: {:type, {:array, :integer}},
        bool: {:type, :boolean},
        time: {:type, :time},
        date: {:type, :date},
        uts: {:type, :utc_datetime},
        nts: {:type, :naive_datetime},
        uuid: {:type, :atom},
        ulid: {:type, :atom},
        other_model_id: {:type, :atom},
      }
    }
  end
end
