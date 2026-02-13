defmodule ArtemisQL.Support.TestModel do
  defmodule INET do
    use Ecto.Type

    @impl true
    def type, do: :inet

    @impl true
    def cast(%Postgrex.INET{} = inet) do
      {:ok, inet}
    end

    @impl true
    def cast(nil) do
      # TODO
      {:ok, nil}
    end

    @impl true
    def cast(str) when is_binary(str) do
      # TODO
      :error
    end

    @impl true
    def load(%Postgrex.INET{} = inet) do
      {:ok, inet}
    end

    @impl true
    def load(nil) do
      {:ok, nil}
    end

    @impl true
    def dump(%Postgrex.INET{} = inet) do
      {:ok, inet}
    end

    @impl true
    def dump(nil) do
      {:ok, nil}
    end
  end

  defmodule CIDR do
    use Ecto.Type

    @impl true
    def type, do: :cidr

    @impl true
    def cast(%Postgrex.INET{} = inet) do
      {:ok, inet}
    end

    @impl true
    def cast(nil) do
      # TODO
      {:ok, nil}
    end

    @impl true
    def cast(str) when is_binary(str) do
      # TODO
      :error
    end

    @impl true
    def load(%Postgrex.INET{} = inet) do
      {:ok, inet}
    end

    @impl true
    def load(nil) do
      {:ok, nil}
    end

    @impl true
    def dump(%Postgrex.INET{} = inet) do
      {:ok, inet}
    end

    @impl true
    def dump(nil) do
      {:ok, nil}
    end
  end

  use Ecto.Schema

  import EctoEnum, only: [defenum: 2, defenum: 3]

  defenum EnumInt,
    none: 0,
    i_1: 1,
    i_2: 2,
    i_3: 3,
    i_4: 4,
    en_1: 5,
    en_2: 6,
    en_3: 7,
    en_4: 8

  defenum EnumString, :string, [
    :none,
    :s_1,
    :s_2,
    :s_3,
    :s_4,
    :en_1,
    :en_2,
    :en_3,
    :en_4
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "test_models" do
    field :serial_id, :integer

    timestamps()

    field :name, :string
    field :notes, :string

    field :enum_i, EnumInt, default: 0
    field :enum_s, EnumString, default: :none
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

    field :inet, INET
    field :cidr, CIDR

    belongs_to :other_model, __MODULE__
  end

  @type t :: %__MODULE__{
    serial_id: integer(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t(),
    uuid: Ecto.UUID.t(),
    ulid: Ecto.ULID.t(),
    other_model_id: Ecto.UUID.t(),
  }

  def search_spec do
    %ArtemisQL.SearchMap{
      allowed_keys: %{
        "id" => true,
        "serial_id" => true,
        "inserted_at" => true,
        "updated_at" => true,
        "name" => true,
        "notes" => true,

        "enum_i" => true,
        "enum_s" => true,
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
        "inet" => true,
        "cidr" => true,
        "other_model_id" => true,
      },
      pair_transform: %{
        id: {:type, :uuid},
        serial_id: {:type, :integer},
        inserted_at: {:type, :utc_datetime},
        updated_at: {:type, :utc_datetime},
        name: {:type, :string},
        notes: {:type, :string},

        enum_i: {:enum, EnumInt},
        enum_s: {:enum, EnumString},

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
        inet: {:type, :inet},
        cidr: {:type, :cidr},
        other_model_id: {:type, :uuid},
      },
      pair_filter: %{
        id: {:type, :uuid},
        serial_id: {:type, :integer},
        inserted_at: {:type, :utc_datetime},
        updated_at: {:type, :utc_datetime},
        name: {:type, :string},
        notes: {:type, :string},

        enum_i: {:type, :atom},
        enum_s: {:type, :atom},

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
        inet: {:type, :inet},
        cidr: {:type, :cidr},
        other_model_id: {:type, :atom},
      }
    }
  end
end
