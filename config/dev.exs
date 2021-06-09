use Mix.Config

config :catena, env: :dev
config :catena_persistence, env: :dev
config :logger, :console, format: "[$level] $message\n"

config :catena_api, CatenaApi.Endpoint,
  http: [port: {:system, :integer, "CATENA_HOST_PORT", 4000}],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
