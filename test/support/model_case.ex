defmodule ArtemisQL.Support.ModelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias ArtemisQL.Support.Repo

      require Repo

      import Ecto
      import Ecto.Query
      import unquote(__MODULE__), except: [setup_databases: 1]
    end
  end

  setup tags do
    :ok = setup_databases(tags)
    :ok
  end

  alias ArtemisQL.Support.Repo
  alias ArtemisQL.Support.TestModel

  def setup_databases(tags) do
    for repo <- Enum.uniq([ArtemisQL.Support.Repo]) do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo)

      unless tags[:async] do
        Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
      end
    end

    :ok
  end

  def insert_test_mode(params) when is_map(params) or is_list(params) do
    %TestModel{}
    |> Ecto.Changeset.change(params)
    |> Repo.insert!()
  end
end
