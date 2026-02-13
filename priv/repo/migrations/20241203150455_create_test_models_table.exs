defmodule ArtemisQL.Support.Repo.Migrations.CreateTestModelsTable do
  use Ecto.Migration

  def change do
    create table(:test_models, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :serial_id, :bigserial, null: false

      timestamps(null: false)

      add :name, :string, null: false
      add :notes, :text, null: true

      add :int, :integer
      add :dec, :decimal
      add :flt, :float
      add :str, :string
      add :jarr, :jsonb
      add :jmap, :jsonb
      add :narr_s, {:array, :string}
      add :narr_i, {:array, :integer}
      add :bool, :boolean
      add :time, :time
      add :date, :date
      add :uts, :utc_datetime_usec
      add :nts, :naive_datetime_usec
      add :uuid, :binary_id
      add :ulid, :binary_id
    end

    alter table(:test_models) do
      # to allow testing associations
      add :other_model_id, references(:test_models, type: :binary_id), null: true
    end
  end
end
