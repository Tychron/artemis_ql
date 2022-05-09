defmodule ArtemisQl.MixProject do
  use Mix.Project

  def project do
    [
      app: :artemis_ql,
      version: "0.2.0",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.10",
      elixirc_options: [
        warnings_as_errors: true,
      ],
      start_permanent: false,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.1"},
      {:timex, "~> 3.6"},
    ]
  end
end
