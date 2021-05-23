defmodule CatenaTest do
  alias Catena.Boundary.{ScheduleManager, UserManager}
  alias Catena.Core.{Event, Habit, HabitHistory, Schedule, User, Utils}
  alias Catena.Core.Repeats.Daily
  alias Ecto.Adapters.SQL.Sandbox

  use ExUnit.Case, async: true

  @moduletag :boundary

  setup _tags do
    :ok = Sandbox.checkout(CatenaPersistence.Repo)
    UserManager.active_users() |> Enum.each(&UserManager.stop/1)
    {:ok, %{}}
  end

  def daily_event, do: Event.new(~N[2020-10-01 00:00:00], repeats: %Daily{interval: 1})

  defp start_schedule_without_history(habit) do
    current_date = ~N[2020-10-22 00:00:00]
    start_date = ~N[2020-10-20 00:00:00]
    end_date = ~N[2020-10-23 00:00:00]

    ScheduleManager.run_schedule(Schedule.new(habit, [], start_date, end_date, current_date))
    habit
  end

  defp start_schedule_without_pending_history(habit) do
    current_date = ~N[2020-10-22 00:00:00]
    start_date = ~N[2020-10-20 00:00:00]
    end_date = ~N[2020-10-23 00:00:00]
    history = [HabitHistory.new(habit, current_date, done: true)]

    ScheduleManager.run_schedule(Schedule.new(habit, history, start_date, end_date, current_date))
    habit
  end

  test "new_user/2 persists a user and starts up a user process" do
    user = Catena.new_user("test@email.com", "password")

    refute is_nil(user.id)
    assert UserManager.running?(user.id)
    assert Utils.validate_password("password", user.password)
  end

  describe "get_user/1" do
    test "returns an existing user given an id" do
      user = Catena.new_user("test@email.com", "password")

      assert user.id == Catena.get_user(id: user.id).id
    end

    test "returns an existing user given an email" do
      user = Catena.new_user("test@email.com", "password")

      assert user.id == Catena.get_user(email: "test@email.com").id
    end

    test "returns nil given a non-existent email" do
      Catena.new_user("test@email.com", "password")

      assert is_nil(Catena.get_user(email: "test1@email.com"))
    end

    test "returns nil given a non-existent id" do
      Catena.new_user("test@email.com", "password")

      assert is_nil(Catena.get_user(id: Utils.new_id()))
    end
  end

  describe "authenticate_user/2" do
    test "returns an ok tuple given a valid email and password" do
      user = Catena.new_user("test@email.com", "password")

      {:ok, returned_user} = Catena.authenticate_user(user.email, "password")
      assert user.id == returned_user.id
    end

    test "returns an error tuple when given a valid email and an invalid password" do
      Catena.new_user("test@email.com", "password")

      assert {:error, :bad_password} == Catena.authenticate_user("test@email.com", "password1")
    end

    test "returns an error tuple when given an invalid email" do
      Catena.new_user("test@email.com", "password")

      assert {:error, :not_found} == Catena.authenticate_user("test1@email.com", "password")
    end
  end

  test "new_habit/3 persists a new habit and starts a schedule process" do
    user = Catena.new_user("test@email.com", "password")
    event = daily_event()
    habit = Catena.new_habit("Test habit", user, [event])

    refute is_nil(habit.id)
    assert ScheduleManager.running?(habit.id)
  end

  test "start/0 starts up processes for existing user and habits" do
    email = "test@user.com"

    active_users = length(UserManager.active_users())
    active_schedules = length(ScheduleManager.active_schedules())

    user =
      email
      |> User.new(username: email, password: Utils.hash_password("password"))
      |> Catena.save_user()

    %Habit{id: habit_id} =
      "Test habit"
      |> Habit.new(user, [daily_event()])
      |> Catena.save_habit()

    Catena.start()

    assert active_users + 1 == length(UserManager.active_users())
    assert active_schedules + 1 == length(ScheduleManager.active_schedules())
    assert UserManager.running?(user.id)
    assert ScheduleManager.running?(habit_id)
  end

  describe "mark_pending_habit/2" do
    test "persists history if marked" do
      user = Catena.new_user("test@email.com", "password")
      event = daily_event()
      opts = [start_schedule_process_fn: &start_schedule_without_history/1]
      habit = Catena.new_habit("Test habit", user, [event], opts)
      ScheduleManager.state(habit.id)

      history = Catena.mark_pending_habit(habit.id, ~N[2020-10-22 00:00:00])
      refute is_nil(history.id)
    end

    test "does nothing if not marked" do
      user = Catena.new_user("test@email.com", "password")
      event = daily_event()
      opts = [start_schedule_process_fn: &start_schedule_without_pending_history/1]
      habit = Catena.new_habit("Test habit", user, [event], opts)

      history = Catena.mark_pending_habit(habit.id, ~N[2020-10-22 00:00:00])
      assert is_nil(history)
    end
  end

  describe "mark_past_habit/2" do
    test "persists history if marked" do
      user = Catena.new_user("test@email.com", "password")
      event = daily_event()
      opts = [start_schedule_process_fn: &start_schedule_without_history/1]
      habit = Catena.new_habit("Test habit", user, [event], opts)

      history = Catena.mark_past_habit(habit.id, ~N[2020-10-21 00:00:00])
      refute is_nil(history.id)
    end

    test "does nothing if not marked" do
      user = Catena.new_user("test@email.com", "password")
      opts = [start_schedule_process_fn: &start_schedule_without_pending_history/1]
      habit = Catena.new_habit("Test habit", user, [daily_event()], opts)
      ScheduleManager.state(habit.id)

      history = Catena.mark_past_habit(habit.id, ~N[2020-10-22 00:00:00])
      assert is_nil(history)
    end
  end

  test "add_event/3 updates the last event, adds a new event then starts a schedule process" do
    user = Catena.new_user("test@email.com", "password")
    habit = Catena.new_habit("Test habit", user, [daily_event()])
    last_event_end_date = ~N[2020-10-10 00:00:00]
    day_before_last_event_date = ~N[2020-10-09 00:00:00]

    event_params = %{
      start_date: last_event_end_date,
      excludes: [],
      repeats: "FREQ=DAILY;INTERVAL=2"
    }

    assert %{events: [first, _second]} = Catena.add_event(habit.id, event_params)
    assert day_before_last_event_date == first.repeats.until
    assert ScheduleManager.running?(habit.id)
  end
end
