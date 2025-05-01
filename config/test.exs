import Config

config :artemis_ql, ecto_repos: [ArtemisQL.Support.Repo]
config :artemis_ql, ArtemisQL.Support.Repo,
  database: "artemis_ql_test",
  username: "artemis_ql_rw",
  pool_size: 10,
  pool_overflow: 0,
  priv: "priv/repo/",
  migration_timestamps: [type: :utc_datetime_usec],
  pool: Ecto.Adapters.SQL.Sandbox
