defmodule ArtemisQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :artemis_ql,
      version: "0.4.0",
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
      deps: deps(),
      package: package(),
      source_url: "https://github.com/Tychron/artemis_ql",
      homepage_url: "https://github.com/Tychron/artemis_ql",
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto, "~> 3.1"},
      {:timex, "~> 3.6"},
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
end
