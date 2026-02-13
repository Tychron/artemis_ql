defmodule ArtemisQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :artemis_ql,
      version: "0.7.0",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: true,
      ],
      start_permanent: false,
      aliases: aliases(),
      deps: deps(),
      package: package(),
      source_url: "https://github.com/Tychron/artemis_ql",
      homepage_url: "https://github.com/Tychron/artemis_ql",
    ]
  end

  def application do
    base =
      [
        extra_applications: [:logger]
      ]

    case Mix.env() do
      :test ->
        [
          {:mod, {ArtemisQL.Support.Application, []}}
          | base
        ]

      _ ->
        base
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_ulid, "~> 0.3"},
      {:ecto, "~> 3.1"},
      {:ecto_sql, "~> 3.1", only: [:test]},
      {:postgrex, "~> 0.11", only: [:test]},
      {:ecto_enum, "~> 1.4", only: [:test]},
      {:jason, "~> 1.0", only: [:test]},
      {:timex, "~> 3.6"},
      {:decimal, "~> 2.0"},
    ]
  end

  defp package do
    [
      maintainers: ["Tychron Developers <developers@tychron.co>"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Tychron/artemis_ql"
      },
    ]
  end

  defp aliases do
    [
      "ecto.seed": ["run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
