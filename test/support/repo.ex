defmodule ArtemisQL.Support.Repo do
  use Ecto.Repo, otp_app: :artemis_ql, adapter: Ecto.Adapters.Postgres
end
