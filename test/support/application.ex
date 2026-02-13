defmodule ArtemisQL.Support.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ArtemisQL.Support.Repo,
    ]

    opts = [
      name: ArtemisQL.Support.Supervisor,
      strategy: :one_for_one
    ]
    Supervisor.start_link(children, opts)
  end
end
