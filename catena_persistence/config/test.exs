use Mix.Config

config :catena_persistence, CatenaPersistence.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: {:system, "CATENA_DB_TEST_NAME"}
