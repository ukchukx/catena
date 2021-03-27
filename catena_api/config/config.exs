# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

catena_host = System.get_env("CATENA_HOST_NAME", "example.com")

# Configures the endpoint
config :catena_api, CatenaApi.Endpoint,
  url: [host: catena_host],
  http: [
    port: {:system, :integer, "CATENA_HOST_PORT", 4000},
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: {:system, "CATENA_SECRET_KEY_BASE"},
  render_errors: [view: CatenaApi.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: CatenaApi.PubSub,
  live_view: [signing_salt: "cG66nitf"],
  check_origin: ["//127.0.0.1:8080", "//#{catena_host}"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :catena,
  persistence_module: CatenaPersistence

config :catena_persistence,
  ecto_repos: [CatenaPersistence.Repo]

config :catena,
  ecto_repos: [CatenaPersistence.Repo]

config :catena_api,
  ecto_repos: [CatenaPersistence.Repo],
  password_reset_ttl: {:system, :integer, "CATENA_PASSWORD_RESET_TTL_MINUTES", 120},
  token_ttl: {:system, :integer, "CATENA_TOKEN_TTL_MINUTES", 120}

config :catena_persistence, CatenaPersistence.Repo,
  username: {:system, "CATENA_DB_USER"},
  password: {:system, "CATENA_DB_PASS"},
  database: {:system, "CATENA_DB_NAME"},
  hostname: {:system, "CATENA_DB_HOST"},
  pool_size: {:system, :integer, "CATENA_DB_POOL_SIZE", 10},
  charset: "utf8mb4",
  collation: "utf8mb4_unicode_ci",
  telemetry_prefix: [:catena, :repo]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
