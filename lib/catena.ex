defmodule Catena do
  alias Catena.Boundary.{ScheduleManager, UserManager, UserValidator}
  alias Catena.Core.{Event, Habit, HabitHistory, Schedule, User, Utils}

  require Logger

  @spec start :: :ok
  def start do
    persistence_module().users()
    |> Enum.each(fn map = %{email: email} ->
      email |> User.new(Keyword.new(map)) |> start_user_process
    end)
  end

  @spec start_user_process(User.t()) :: User.t()
  def start_user_process(user = %User{id: id}) when not is_nil(id) do
    UserManager.start_user(user)

    with true <- UserManager.running?(id) do
      persistence_module().user_habits(id)
      |> Enum.map(&%{&1 | user: user})
      |> Enum.map(&struct(Habit, %{&1 | event: inflate_event(&1.event)}))
      |> Enum.map(&start_schedule_process/1)
    end

    user
  end

  @spec start_schedule_process(Habit.t()) :: Habit.t()
  def start_schedule_process(habit = %Habit{id: id, user: user}) when not is_nil(id) do
    history =
      persistence_module().habit_history_for_user(id)
      |> Enum.map(&%{&1 | user: user, habit: habit})

    current_date = NaiveDateTime.utc_now()
    start_date = current_date |> reset_time() |> start_of_year
    end_date = end_of_year(start_date)

    ScheduleManager.run_schedule(Schedule.new(habit, history, start_date, end_date, current_date))
    habit
  end

  @spec new_user(binary, binary) :: keyword | User.t()
  def new_user(email, password) do
    with nil <- get_user(email: email),
         :ok <- UserValidator.errors(%{email: email, password: password}) do
      email
      |> User.new(username: email, password: Utils.hash_password(password))
      |> save_user
      |> start_user_process
    else
      errors when is_list(errors) -> errors
      _user -> [{:email, "has been taken"}]
    end
  end

  @spec update_user(binary, map) :: keyword | User.t()
  def update_user(id, params) do
    with %{email: email} <- get_user(id: id),
         :ok <- UserValidator.errors(Map.put_new(params, :email, email)) do
      params =
        params
        |> Map.get(:password)
        |> case do
          nil -> params
          password -> %{params | password: Utils.hash_password(password)}
        end

      id
      |> UserManager.update(params)
      |> save_user
    else
      errors when is_list(errors) -> errors
      nil -> [{:user, "does not exist"}]
    end
  end

  @spec new_habit(binary, User.t(), Event.t(), keyword) :: Habit.t()
  def new_habit(title, %User{} = user, %Event{} = event, opts \\ []) when is_binary(title) do
    start_schedule_process_fn =
      Keyword.get(opts, :start_schedule_process_fn, &start_schedule_process/1)

    title
    |> Habit.new(user, event, opts)
    |> save_habit()
    |> start_schedule_process_fn.()
  end

  @spec mark_pending_habit(binary, NaiveDateTime.t()) :: nil | HabitHistory.t()
  def mark_pending_habit(id, date) do
    case ScheduleManager.mark_pending(id, date) do
      :not_running ->
        Logger.warn("Habit #{id} is not running")
        nil

      nil ->
        Logger.info("Habit #{id} is not pending on #{date}")
        nil

      history ->
        Logger.info("Pending habit #{id} marked on #{date}")
        save_habit_history(history)
    end
  end

  @spec mark_past_habit(binary, NaiveDateTime.t()) :: nil | HabitHistory.t()
  def mark_past_habit(id, date) do
    case ScheduleManager.mark_past(id, date) do
      :not_running ->
        Logger.warn("Habit #{id} is not running")
        nil

      nil ->
        Logger.info("Habit #{id} is not pending on #{date}")
        nil

      history ->
        Logger.info("Past habit #{id} marked on #{date}")
        save_habit_history(history)
    end
  end

  @spec get_user(keyword) :: nil | User.t()
  def get_user(id: id) do
    case UserManager.state(id) do
      :not_running -> nil
      %{user: user} -> user
    end
  end

  def get_user(email: email) do
    UserManager.active_users()
    |> Enum.map(&UserManager.state/1)
    |> Enum.find(fn
      %{user: %{email: ^email}} -> true
      _ -> false
    end)
    |> case do
      nil -> nil
      %{user: user} -> user
    end
  end

  @spec authenticate_user(binary, binary) ::
          {:error, :bad_password | :not_found} | {:ok, User.t()}
  def authenticate_user(email, password) do
    with %User{} = user <- get_user(email: email),
         true <- Utils.validate_password(password, user.password) do
      {:ok, user}
    else
      false -> {:error, :bad_password}
      nil -> {:error, :not_found}
    end
  end

  @spec get_schedule(binary) :: {:error, :not_found} | {:ok, Schedule.t()}
  def get_schedule(habit_id) do
    case ScheduleManager.state(habit_id) do
      :not_running -> {:error, :not_found}
      schedule -> {:ok, schedule}
    end
  end

  @spec save_user(User.t()) :: User.t()
  def save_user(user), do: persistence_module().save_user(user, &Utils.new_id/0)

  @spec save_habit(Habit.t()) :: Habit.t()
  def save_habit(habit), do: persistence_module().save_habit(habit, &Utils.new_id/0)

  @spec save_habit_history(HabitHistory.t()) :: HabitHistory.t()
  def save_habit_history(history),
    do: persistence_module().save_habit_history(history, &Utils.new_id/0)

  @spec persistence_module :: atom
  def persistence_module, do: Application.get_env(:catena, :persistence_module)

  #
  #
  #

  defp inflate_event(map = %{repeats: nil, start_date: s}), do: Event.new(s, Keyword.new(map))

  defp inflate_event(map = %{repeats: repeats, start_date: s}) do
    Event.new(s, Keyword.new(%{map | repeats: Event.inflate_repetition(repeats)}))
  end

  defp reset_time(date_time) do
    %{date_time | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  defp start_of_year(date_time), do: %{date_time | month: 1, day: 1}

  defp end_of_year(date_time), do: %{date_time | month: 12, day: 31}
end
