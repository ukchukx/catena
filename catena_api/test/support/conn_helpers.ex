defmodule CatenaApi.ConnHelpers do
  @moduledoc false

  def authenticated_conn(conn, user) do
    token = CatenaApi.Token.get_token(%{email: user.email, id: user.id})

    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  def fresh_conn,
    do:
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("content-type", "application/json")
end
