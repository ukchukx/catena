defmodule CatenaApi.AuthController do
  alias Catena.Core.Utils

  use CatenaApi, :controller
  require Logger

  def signin(conn, %{"email" => email, "password" => pass}) do
    Logger.info("'#{email}' attempting to sign in")

    with {:ok, user} <- Catena.authenticate_user(email, pass),
         token <- CatenaApi.Token.get_token(%{email: email, id: user.id}) do
      Logger.info("Authentication attempt by '#{email}' succeeded")

      json(conn, %{success: true, data: user_to_map(user), token: token})
    else
      {:error, _} = err ->
        Logger.warn("Authentication attempt by '#{email}' failed due to #{inspect err}")

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

      conn
      |> put_status(201)
      |> json(%{success: true, data: user_to_map(user), token: token})
    else
      errors ->
        errors = merge_errors(errors)
        Logger.warn("Sign up attempt by '#{email}' failed due to #{inspect errors}")

        conn
        |> put_status(400)
        |> json(%{success: false, message: "Validation failed", errors: errors})
    end
  end

  def forgot(conn, %{"email" => email}) do
    with %{}  <- Catena.get_user(email: email),
         token <- Utils.random_string(20),
         hashed_token <- Utils.hash_password(token),
         %{} <- Catena.save_reset(email, hashed_token, expiry_ttl_in_seconds()) do
      Task.async(fn -> send_email(email, token) end)
      json(conn, %{success: true, message: "Password reset email sent"})
    else
      {:error, ch} ->
        Logger.warn("Cannot send reset token for '#{email}': could not save token: #{inspect ch}")

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
         true <- valid_token?(token, record.token),
         %{id: id} <- Catena.get_user(email: email),
         %{} = user <- Catena.update_user(id, %{password: pass}),
         token <- CatenaApi.Token.get_token(%{email: email, id: id}) do
      Logger.info("Password reset by '#{email}' was successful")
      json(conn, %{success: true, data: user_to_map(user), token: token})
    else
      false ->
        Logger.warn("Reset token for '#{email}' has expired")

        conn
        |> put_status(406)
        |> json(%{success: false, message: "Reset token expired"})

      {:error, ch} ->
        Logger.warn("Reset token for '#{email}' could not be deleted: #{inspect ch}")

        conn
        |> put_status(500)
        |> json(%{success: false, message: "Reset token could not be deleted"})

      nil ->
        Logger.warn("Reset token (or user process) for '#{email}' does not exist")

        conn
        |> put_status(400)
        |> json(%{success: false, message: "Reset token not found"})
    end
  end

  def me(%{assigns: %{user: %{id: id}}} = conn, _params) do
    json(conn, %{success: true, data: [id: id] |> Catena.get_user() |> user_to_map()})
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

  defp user_to_map(user) do
    user |> Map.from_struct() |> Map.drop(~w[__struct__ password]a)
  end

  defp merge_errors(errors) do
    errors
    |> Enum.group_by(
      fn {field, _message} -> field end,
      fn {_field, message} -> message end
    )
    |> Map.new
  end

  defp valid_token?(token, token_hash) do
    Utils.validate_password(token, token_hash)
  end

  def expiry_ttl_in_seconds, do: Application.get_env(:catena_api, :password_reset_ttl) * 60

  if Application.get_env(:catena, :env) == :test do
    defp send_email(_email, _token), do: :ok
  else
    # TODO: Complete
    defp send_email(email, token) do
      _text = email_text(email, token)
      _subject = "Password Reset"
      _from = {"noreply@catena.com.ng", "Catena App"}
      :ok
    end
  end

  defp email_text(email, token) do
    """
    <h2>Hello, #{email}!</h2>
    <p>You are receiving this email because we received a password reset request for your account.</p>
    <p><a href='https://catena.com.ng/#/app/reset?email=#{email}&token=#{token}'>Reset Password</a></p>
    <p>If you did not request a password reset, no further action is required.</p>
    <p>Regards</p>
    """
  end
end
