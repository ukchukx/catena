defmodule CatenaApi.Utils do
  @moduledoc false
  alias Catena.Core.Utils

  def user_to_map(user), do: user |> Map.from_struct() |> Map.drop(~w[__struct__ password]a)

  def schedule_to_map(%{habit: habit, past_events: past, future_events: future}) do
    past = Enum.map(past, &habit_history_to_map/1)
    future = Enum.map(future, &habit_history_to_map/1)
    habit = %{events: %{data: events}} = CatenaPersistence.Habit.from_model(habit)

    habit
    |> Map.drop([:user])
    |> Map.put(:history, past ++ future)
    |> Map.put(:events, events)
  end

  def habit_history_to_map(%{date: date} = history) do
    data = CatenaPersistence.HabitHistory.from_model(history)

    data
    |> Map.get(:id)
    |> case do
      nil -> Map.put(data, :done, false)
      _ -> Map.put(data, :done, true)
    end
    |> Map.put(:date, NaiveDateTime.to_iso8601(date))
  end

  def merge_errors(errors) do
    errors
    |> Enum.group_by(
      fn {field, _message} -> field end,
      fn {_field, message} -> message end
    )
    |> Map.new()
  end

  def valid_token?(token, token_hash), do: Utils.validate_password(token, token_hash)

  def expiry_ttl_in_seconds, do: Application.get_env(:catena_api, :password_reset_ttl) * 60

  if Application.get_env(:catena, :env) == :test do
    def send_email(_email, _token), do: :ok
  else
    def send_email(email, token) do
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
