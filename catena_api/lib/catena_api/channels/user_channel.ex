defmodule CatenaApi.UserChannel do
  @moduledoc false

  use CatenaApi, :channel

  require Logger

  def join("user:" <> id, _payload, %{assigns: %{user_id: id}} = socket) do
    Logger.info("User '#{id}' joined their channel")
    {:ok, socket}
  end

  def join(topic, _payload, %{assigns: attrs} = _socket) do
    Logger.warn("User '#{attrs[:user_id]}' tried to join channel '#{topic}'")
    {:error, "Unauthorized"}
  end
end
