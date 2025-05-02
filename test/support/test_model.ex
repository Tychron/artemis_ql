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
        #
        "jmap" => true,
        "jmap_s" => true,
        "jmap_i" => true,
        "jmap_f" => true,
        "jmap_d" => true,
        "jmap_b" => true,
        "jmap_o_s" => true,
        "jmap_o_i" => true,
        "jmap_o_f" => true,
        "jmap_o_d" => true,
        "jmap_o_b" => true,
        #
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
        #
        jmap: {:type, :map},
        jmap_s: {:type, :string},
        jmap_i: {:type, :integer},
        jmap_f: {:type, :float},
        jmap_d: {:type, :decimal},
        jmap_b: {:type, :boolean},
        jmap_o_s: {:type, :string},
        jmap_o_i: {:type, :integer},
        jmap_o_f: {:type, :float},
        jmap_o_d: {:type, :decimal},
        jmap_o_b: {:type, :boolean},
        #
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
        #
        jmap: {:type, :map},
        jmap_s: {:jsonb, :string, :jmap, ["s"]},
        jmap_i: {:jsonb, :integer, :jmap, ["i"]},
        jmap_f: {:jsonb, :float, :jmap, ["f"]},
        jmap_d: {:jsonb, :decimal, :jmap, ["d"]},
        jmap_b: {:jsonb, :boolean, :jmap, ["b"]},
        jmap_o_s: {:jsonb, :string, :jmap, ["o", "s"]},
        jmap_o_i: {:jsonb, :integer, :jmap, ["o", "i"]},
        jmap_o_f: {:jsonb, :float, :jmap, ["o", "f"]},
        jmap_o_d: {:jsonb, :decimal, :jmap, ["o", "d"]},
        jmap_o_b: {:jsonb, :boolean, :jmap, ["o", "b"]},
        #
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
