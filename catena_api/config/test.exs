use Mix.Config

config :catena, env: :test
# We don't run a server during test. If one is required,
# you can enable the server option below.
config :catena_api, CatenaApi.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :comeonin, :bcrypt_log_rounds, 4

config :catena_persistence, CatenaPersistence.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: {:system, "CATENA_DB_TEST_NAME"}
