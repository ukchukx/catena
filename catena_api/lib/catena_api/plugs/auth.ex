defmodule CatenaApi.Plug.Auth do
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(%{request_path: path} = conn, _default) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- CatenaApi.Token.verify_and_validate(token, CatenaApi.Token.signer()) do
      assign(conn, :user, %{id: claims["id"], email: claims["email"]})
    else
      {:error, [message: "Invalid token", claim: "exp", claim_val: _]} = err ->
        Logger.warn("Cannot access '#{path}'. Token expired. ")
        unauthenticated(conn)

      [] ->
        Logger.warn("Authorization to '#{path}' failed as token was not provided")
        unauthorized(conn)

      err ->
        Logger.warn("Authorization to '#{path}' failed with #{inspect err}")
        unauthorized(conn)
    end
  end

  defp unauthorized(conn), do: error(conn, 401, "Unauthorized")

  defp unauthenticated(conn), do: error(conn, 403, "Unauthenticated")

  defp error(conn, status_code, msg) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status_code, Jason.encode!(%{message: msg, success: false}))
    |> halt
  end
end
