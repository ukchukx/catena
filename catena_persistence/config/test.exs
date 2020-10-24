use Mix.Config

config :catena_persistence, CatenaPersistence.Repo,
  database: {:system, "CATENA_DB_TEST_NAME"},
  pool:​ Ecto.Adapters.SQL.Sandbox
