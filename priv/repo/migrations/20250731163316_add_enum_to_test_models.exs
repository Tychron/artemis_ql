defmodule ArtemisQL.Support.Repo.Migrations.AddEnumToTestModels do
  use Ecto.Migration

  def change do
    alter table(:test_models) do
      add :enum_i, :integer, default: 0
      add :enum_s, :string, default: "none"
    end
  end
end
