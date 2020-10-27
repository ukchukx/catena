defmodule CatenaPersistence.MixProject do
  use Mix.Project

  def project do
    [
      app: :catena_persistence,
      version: "1.0.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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
      {:ecto_sql, "~> 3.5.1"},
      {:jason, "~> 1.0"},
      {:myxql, "~> 0.4.3"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.create", "ecto.migrate"],
      reset: ["ecto.drop", "setup"],
      test:  ["ecto.drop --quiet", "ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
