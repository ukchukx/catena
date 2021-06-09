use Mix.Config

config :catena, env: :test
config :catena_persistence, env: :test

config :comeonin, :bcrypt_log_rounds, 4

config :catena_persistence, CatenaPersistence.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: {:system, "CATENA_DB_TEST_NAME"}

config :catena_api, CatenaApi.Endpoint,
  http: [port: 4002],
  server: false

config :logger, level: :warn
