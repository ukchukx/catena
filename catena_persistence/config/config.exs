use Mix.Config

config :catena_persistence,
  ecto_repos: [CatenaPersistence.Repo]

config :catena_persistence, CatenaPersistence.Repo,
  username: {:system, "CATENA_DB_USER"},
  password: {:system, "CATENA_DB_PASS"},
  database: {:system, "CATENA_DB_NAME"},
  hostname: {:system, "CATENA_DB_HOST"},
  pool_size: {:system, :integer, "CATENA_DB_POOL_SIZE", 10},
  charset: "utf8mb4",
  collation: "utf8mb4_unicode_ci",
  telemetry_prefix: [:catena, :repo]


config :logger, level: :info

import_config "#{Mix.env()}.exs"
