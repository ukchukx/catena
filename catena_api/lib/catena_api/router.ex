defmodule CatenaApi.Router do
  use CatenaApi, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Telemetry, event_prefix: [:catena, :plug]
    plug CatenaApi.MetricsExporter
  end

  pipeline :auth do
    plug CatenaApi.Plug.Auth
  end

  scope "/api", CatenaApi do
    pipe_through :api

    post "/signup", AuthController, :signup
    post "/signin", AuthController, :signin
    post "/forgot", AuthController, :forgot
    post "/reset", AuthController, :reset
    get "/public-habit/:id", HabitController, :public_habit
  end

  scope "/api", CatenaApi do
    pipe_through [:api, :auth]

    get "/me", AuthController, :me
    post "/change_password", AuthController, :change_password

    post "/habits", HabitController, :create
    get "/habits", HabitController, :habits
    put "/habits/:id", HabitController, :update
    get "/habits/:id", HabitController, :habit
    post "/habits/:id/mark-pending", HabitController, :mark_pending
    delete "/habits/:id", HabitController, :delete
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: CatenaApi.Telemetry
    end
  end
end
