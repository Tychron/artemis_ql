defmodule ArtemisQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :artemis_ql,
      version: "0.2.2",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.11",
      elixirc_options: [
        warnings_as_errors: true,
      ],
      start_permanent: false,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.1"},
      {:timex, "~> 3.6"},
    ]
  end
end
