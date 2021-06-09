use Mix.Config

config :catena, env: :prod
config :catena_persistence, env: :prod

config :catena_api, CatenaApi.Endpoint,
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
