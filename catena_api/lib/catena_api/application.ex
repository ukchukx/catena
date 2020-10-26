defmodule CatenaApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    Confex.resolve_env!(:catena_api)
    CatenaApi.Metrics.Setup.setup()

    children = [
      # Start the Telemetry supervisor
      CatenaApi.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CatenaApi.PubSub},
      # Start the Endpoint (http/https)
      CatenaApi.Endpoint
      # Start a worker by calling: CatenaApi.Worker.start_link(arg)
      # {CatenaApi.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CatenaApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CatenaApi.Endpoint.config_change(changed, removed)
    :ok
  end
end
