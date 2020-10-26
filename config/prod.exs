use Mix.Config

config :catena, env: :prod

config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :catena_api, CatenaApi.Endpoint,
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json"
