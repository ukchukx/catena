defmodule Catena do
  alias Catena.Boundary.{PasswordReset, ScheduleManager, UserManager, UserValidator}
  alias Catena.Core.{Event, Habit, HabitHistory, Schedule, User, Utils}

  require Logger

  @spec start :: :ok
  def start do
    persistence_module().users()
    |> Enum.each(fn map = %{email: email} ->
      email |> User.new(Keyword.new(map)) |> start_user_process
    end)
  end

  @spec stop :: :ok
  def stop, do: UserManager.active_users() |> Enum.each(&UserManager.stop/1)

  @spec start_user_process(User.t()) :: User.t()
  def start_user_process(user = %User{id: id}) when not is_nil(id) do
    UserManager.start_user(user)

    with true <- UserManager.running?(id) do
      persistence_module().user_habits(id)
      |> Enum.map(fn habit = %{events: events} ->
        struct(Habit, %{habit | events: Enum.map(events, &inflate_event/1), user: user})
      end)
      |> Enum.map(&start_schedule_process/1)
    end

    user
  end

  @spec restart_user_schedules(User.t(), [binary]) :: [Schedule.t()]
  def restart_user_schedules(user = %{id: id}, habit_ids) do
    persistence_module().user_habits(id)
    |> Enum.filter(&(&1.id in habit_ids))
    |> Enum.map(fn habit = %{events: events} ->
      struct(Habit, %{habit | events: Enum.map(events, &inflate_event/1), user: user})
    end)
    |> Enum.map(&start_schedule_from_habit/1)
  end

  @spec start_schedule_process(Habit.t()) :: Schedule.t()
  def start_schedule_process(habit = %Habit{id: id, user: user}) when not is_nil(id) do
    schedule = start_schedule_from_habit(habit)
    UserManager.add_habit(user.id, habit)
    schedule
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

  @spec new_habit(binary, User.t(), [Event.t()], keyword) :: Habit.t()
  def new_habit(title, %User{} = user, events, opts \\ []) when is_binary(title) do
    start_schedule_process_fn =
      Keyword.get(opts, :start_schedule_process_fn, &start_schedule_process/1)

    habit =
      title
      |> Habit.new(user, events, opts)
      |> save_habit()

    start_schedule_process_fn.(habit)
    habit
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
        history
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
        history
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

  @spec get_habits(binary) :: [Schedule.t()]
  def get_habits(user_id) do
    case UserManager.state(user_id) do
      :not_running -> []
      %{habits: habits} -> Enum.map(habits, &get_habit/1)
    end
  end

  @spec get_habit(binary) :: nil | Schedule.t()
  def get_habit(id) do
    case ScheduleManager.state(id) do
      :not_running -> nil
      %Schedule{past_events: past} = schedule -> %{schedule | past_events: Enum.reverse(past)}
    end
  end

  @spec delete_habit(binary) :: :ok
  def delete_habit(id) do
    case get_habit(id) do
      nil ->
        :ok

      %{habit: %Habit{user: %{id: user_id}} = habit} ->
        ScheduleManager.stop(id)
        UserManager.remove_habit(user_id, habit)
        flush_habit(habit)
    end
  end

  @spec update_habit(binary, map) :: Habit.t() | nil
  def update_habit(id, params) do
    case get_habit(id) do
      nil ->
        nil

      %{habit: %Habit{} = habit} ->
        habit =
          habit
          |> struct(Map.take(params, ~w[title visibility archived]a))
          |> save_habit()

        ScheduleManager.update_habit(id, params)
        habit
    end
  end

  @spec add_event(binary, map, NaiveDateTime.t()) :: Habit.t() | nil
  def add_event(id, event_params, until_for_previous_event) do
    case get_habit(id) do
      nil ->
        nil

      %{habit: %Habit{events: events} = habit} ->
        last_event =
          events
          |> List.last()
          |> Map.put(:until, until_for_previous_event)

        event =
          event_params
          |> Map.take(~w[start_date repeats excludes]a)
          |> inflate_event()

        events =
          events
          |> List.replace_at(-1, last_event)
          |> List.insert_at(-1, event)

        habit =
          habit
          |> struct(%{events: events})
          |> save_habit()

        ScheduleManager.stop(id)
        start_schedule_process(habit)
        habit
    end
  end

  @spec save_reset(binary, binary, non_neg_integer()) :: map
  def save_reset(email, token, ttl_seconds),
    do: PasswordReset.put(email, token, ttl_seconds) |> Map.put(:email, email)

  @spec get_reset(binary) :: nil | map
  def get_reset(email) do
    case PasswordReset.get(email) do
      nil -> nil
      record -> Map.put(record, :email, email)
    end
  end

  @spec delete_reset(binary) :: :ok
  def delete_reset(email), do: PasswordReset.delete(email)

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

  @spec flush_habit(Habit.t()) :: :ok
  def flush_habit(habit), do: persistence_module().delete_habit(habit)

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

  defp end_of_year(date_time), do: %{date_time | month: 12, day: 31, hour: 23}

  defp start_schedule_from_habit(habit = %Habit{id: id, user: user}) do
    slim_habit = %Habit{
      user: %User{id: user.id},
      id: id,
      title: habit.title,
      archived: habit.archived
    }

    current_date = NaiveDateTime.utc_now()
    start_date = current_date |> reset_time() |> start_of_year
    end_date = end_of_year(start_date)

    history =
      persistence_module().habit_history_for_habit(id)
      |> Enum.map(fn %{date: date, id: id} ->
        HabitHistory.new(slim_habit, date, done: true, id: id)
      end)

    schedule = Schedule.new(habit, history, start_date, end_date, current_date)
    ScheduleManager.run_schedule(schedule)
    schedule
  end
end
