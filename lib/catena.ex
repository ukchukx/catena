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

  @spec new_user(binary, binary) :: keyword | {:error, :email_exists} | User.t()
  def new_user(email, password) do
    with nil <- persistence_module().get_user_by_email(email),
         :ok <- UserValidator.errors(%{email: email, password: password}) do
      email
      |> User.new(username: email, password: Utils.hash_password(password))
      |> save_user
      |> start_user_process
    else
      errors when is_list(errors) -> errors
      _user -> {:error, :email_exists}
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
        Logger.warn("Habit #{id} is not running", habit: id)
        nil

      nil ->
        Logger.info("Habit #{id} is not pending on #{date}", habit: id)
        nil

      history ->
        Logger.info("Pending habit #{id} marked on #{date}", habit: id)
        save_habit_history(history)
    end
  end

  @spec mark_past_habit(binary, NaiveDateTime.t()) :: nil | HabitHistory.t()
  def mark_past_habit(id, date) do
    case ScheduleManager.mark_past(id, date) do
      :not_running ->
        Logger.warn("Habit #{id} is not running", habit: id)
        nil

      nil ->
        Logger.info("Habit #{id} is not pending on #{date}", habit: id)
        nil

      history ->
        Logger.info("Past habit #{id} marked on #{date}", habit: id)
        save_habit_history(history)
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

  # def test do
  #   user = User.new("test@email.com")

  #   event =
  #     Catena.Core.Event.new(~N[2020-10-01 00:00:00],
  #       repeats: %Catena.Core.Repeats.Daily{interval: 1}
  #     )

  #   habit = Habit.new("Test habit", user, event)
  #   add_habit("7ef8cbb9-b6d9-4514-b455-44e731ae658f", habit)
  # end
end
