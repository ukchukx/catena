defmodule CatenaApi.Plug.Auth do
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(%{request_path: path} = conn, _default) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- CatenaApi.Token.verify_and_validate(token, CatenaApi.Token.signer()) do
      assign(conn, :user, %{id: claims["id"], email: claims["email"]})
    else
      [] ->
        Logger.warn("Authorization to '#{path}' failed as token was not provided")
        unauthorized(conn)
      err ->
        Logger.warn("Authorization to '#{path}' failed with #{inspect err}")
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(401, Jason.encode!(%{message: "Unauthorized", success: false}))
    |> halt
  end
end
