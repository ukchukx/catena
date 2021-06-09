defmodule CatenaPersistence.MixProject do
  use Mix.Project

  def project do
    [
      app: :catena_persistence,
      version: "1.0.0",
      elixir: "~> 1.10",
      config_path: "../config/config.exs",
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CatenaPersistence.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:confex, "~> 3.4.0"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.5.1"},
      {:jason, "~> 1.0"},
      {:myxql, "~> 0.4.3"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.create", "ecto.migrate"],
      reset: ["ecto.drop", "setup"],
      test: ["ecto.drop --quiet", "ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
