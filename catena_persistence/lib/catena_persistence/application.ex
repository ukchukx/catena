defmodule CatenaPersistence.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    Confex.resolve_env!(:catena_persistence)

    children = [
      CatenaPersistence.Repo
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CatenaPersistence.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _} = res ->
        if Application.get_env(:catena_persistence, :env) != :test do
          CatenaPersistence.Migrate.run()
        end

        res
      err_res -> err_res
    end
  end
end
