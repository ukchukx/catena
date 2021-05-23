defmodule CatenaApi.UserSocket do
  @moduledoc false

  use Phoenix.Socket

  require Logger

  ## Channels
  channel "user:*", CatenaApi.UserChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token}, socket, connect_info) do
    case CatenaApi.Token.verify_and_validate(token, CatenaApi.Token.signer()) do
      {:ok, %{"id" => user_id}} ->
        {:ok, assign(socket, :user_id, user_id)}

      err ->
        Logger.warn(
          "Refuse socket connection: err = #{inspect(err)}, info = #{inspect(connect_info)}"
        )

        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     CatenaApi.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(%{assigns: %{user_id: id}} = _socket), do: "user_socket:#{id}"
  def id(_socket), do: nil
end
