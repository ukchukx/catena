defmodule CatenaApi.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use CatenaApi.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  alias Ecto.Adapters.SQL.Sandbox
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import CatenaApi.ConnCase
      import CatenaApi.ConnHelpers

      alias CatenaApi.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint CatenaApi.Endpoint
    end
  end

  setup _tags do
    :ok = Sandbox.checkout(CatenaPersistence.Repo)
    {:ok, conn: CatenaApi.ConnHelpers.fresh_conn()}
  end
end
