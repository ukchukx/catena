defmodule Catena.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    Confex.resolve_env!(:catena)

    children = [
      {Registry, [name: Catena.Registry.ScheduleManager, keys: :unique]},
      {Registry, [name: Catena.Registry.UserManager, keys: :unique]},
      {DynamicSupervisor, [name: Catena.Supervisor.ScheduleManager, strategy: :one_for_one]},
      {DynamicSupervisor, [name: Catena.Supervisor.UserManager, strategy: :one_for_one]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Catena.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _} = x ->
        if Application.get_env(:catena, :env) != :test do
          Logger.info("Load active users")
          Catena.start()
        end

        x

      x ->
        x
    end
  end
end
