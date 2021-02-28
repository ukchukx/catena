defmodule CatenaApi.AuthController do
  @moduledoc false

  alias Catena.Core.Utils

  use CatenaApi, :controller
  require Logger

  def signin(conn, %{"email" => email, "password" => pass}) do
    Logger.info("'#{email}' attempting to sign in")

    with {:ok, user = %{id: id}} <- Catena.authenticate_user(email, pass),
         token <- CatenaApi.Token.get_token(%{email: email, id: id}) do
      Logger.info("Authentication attempt by '#{email}' succeeded")

      habits =
        id
        |> Catena.get_habits()
        |> Enum.map(&CatenaApi.Utils.schedule_to_map/1)

      user =
        user
        |> CatenaApi.Utils.user_to_map()
        |> Map.put(:habits, habits)

      json(conn, %{success: true, data: user, token: token})
    else
      {:error, _} = err ->
        Logger.warn("Authentication attempt by '#{email}' failed due to #{inspect(err)}")

        conn
        |> put_status(403)
        |> json(%{success: false, message: "Invalid email/password"})
    end
  end

  def signup(conn, %{"email" => email, "password" => pass}) do
    Logger.info("'#{email}' attempting to sign up")

    with %{} = user <- Catena.new_user(email, pass),
         token <- CatenaApi.Token.get_token(%{email: email, id: user.id}) do
      Logger.info("Sign up attempt by '#{email}' succeeded")

      user = user |> CatenaApi.Utils.user_to_map() |> Map.put(:habits, [])

      conn
      |> put_status(201)
      |> json(%{success: true, data: user, token: token})
    else
      errors ->
        errors = CatenaApi.Utils.merge_errors(errors)
        Logger.warn("Sign up attempt by '#{email}' failed due to #{inspect(errors)}")

        conn
        |> put_status(400)
        |> json(%{success: false, message: "Validation failed", errors: errors})
    end
  end

  def forgot(conn, %{"email" => email}) do
    with %{} <- Catena.get_user(email: email),
         token <- Utils.random_string(20),
         hashed_token <- Utils.hash_password(token),
         %{} <- Catena.save_reset(email, hashed_token, CatenaApi.Utils.expiry_ttl_in_seconds()) do
      Task.async(fn -> CatenaApi.Utils.send_email(email, token) end)
      json(conn, %{success: true, message: "Password reset email sent"})
    else
      {:error, ch} ->
        Logger.warn(
          "Cannot send reset token for '#{email}': could not save token: #{inspect(ch)}"
        )

        conn
        |> put_status(400)
        |> json(%{success: false})

      nil ->
        Logger.warn("Cannot send reset token for '#{email}': does not exist")

        conn
        |> put_status(400)
        |> json(%{success: false})
    end
  end

  def reset(conn, %{"email" => email} = params) do
    with %{"token" => token, "password" => pass} <- params,
         %{} = record <- Catena.get_reset(email),
         :ok <- Catena.delete_reset(email),
         true <- CatenaApi.Utils.valid_token?(token, record.token),
         %{id: id} <- Catena.get_user(email: email),
         %{} = user <- Catena.update_user(id, %{password: pass}),
         token <- CatenaApi.Token.get_token(%{email: email, id: id}) do
      Logger.info("Password reset by '#{email}' was successful")

      habits =
        id
        |> Catena.get_habits()
        |> Enum.map(&CatenaApi.Utils.schedule_to_map/1)

      user =
        user
        |> CatenaApi.Utils.user_to_map()
        |> Map.put(:habits, habits)

      json(conn, %{success: true, data: user, token: token})
    else
      false ->
        Logger.warn("Reset token for '#{email}' has expired")

        conn
        |> put_status(406)
        |> json(%{success: false, message: "Reset token expired"})

      nil ->
        Logger.warn("Reset token (or user process) for '#{email}' does not exist")

        conn
        |> put_status(400)
        |> json(%{success: false, message: "Reset token not found"})

      err ->
        Logger.warn("Reset token for '#{email}' could not be deleted: #{inspect(err)}")

        conn
        |> put_status(500)
        |> json(%{success: false, message: "Reset token could not be deleted"})
    end
  end

  def me(%{assigns: %{user: %{id: id}}} = conn, _params) do
    user = Catena.get_user(id: id)

    habits =
      id
      |> Catena.get_habits()
      |> Enum.map(&CatenaApi.Utils.schedule_to_map/1)

    user =
      user
      |> CatenaApi.Utils.user_to_map()
      |> Map.put(:habits, habits)

    json(conn, %{success: true, data: user})
  end

  def change_password(%{assigns: %{user: %{id: id, email: email}}} = conn, params) do
    Logger.info("Password change attempt by '#{email}'")

    with %{"password" => pass, "new_password" => new_pass} <- params,
         {:ok, %{}} <- Catena.authenticate_user(email, pass),
         %{} = _user <- Catena.update_user(id, %{password: new_pass}) do
      Logger.info("Password change attempt by '#{email}' was successful")
      json(conn, %{success: true, message: "Password updated"})
    else
      {:error, :bad_password} ->
        Logger.warn("Password change attempt by '#{email}' failed: incorrect current password")

        conn
        |> put_status(400)
        |> json(%{success: false, message: "Current password could not be verified."})
    end
  end
end
