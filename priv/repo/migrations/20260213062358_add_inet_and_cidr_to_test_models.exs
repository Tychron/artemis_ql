defmodule ArtemisQL.Support.Repo.Migrations.AddInetAndCidrToTestModels do
  use Ecto.Migration

  def change do
    alter table(:test_models) do
      add :inet, :inet
      add :cidr, :cidr
    end
  end
end
