defmodule CatenaApi.HabitControllerTest do
  alias Catena.Core.{Event, HabitHistory, Schedule}
  alias Catena.Core.Repeats.Daily
  alias Catena.Boundary.ScheduleManager

  use CatenaApi.ConnCase

  setup %{conn: conn} do
    user = Catena.new_user("test@email.com", "password")
    opts = [start_schedule_process_fn: &start_schedule/1]
    habit = Catena.new_habit("Uno habit", user, daily_event(), opts)

    on_exit(fn ->
      Catena.stop()
    end)

    {:ok, conn: authenticated_conn(conn, user), conn2: conn, user: user, habit: habit}
  end

  def daily_event, do: Event.new(~N[2020-10-15 00:00:00], repeats: %Daily{interval: 1})

  defp start_schedule(habit) do
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

  describe "creating a habit" do
    test "succeeds with valid params", %{conn: conn, user: %{id: user_id}} do
      attrs = %{
        title: "Test habit",
        start_date: NaiveDateTime.to_iso8601(~N[2020-10-01 00:00:00]),
        visibility: "private",
        rrule: "FREQ=DAILY;INTERVAL=1"
      }
      conn = post conn, Routes.habit_path(conn, :create), attrs
      json = json_response(conn, 201)

      assert json["success"]
      assert get_in(json, ["data", "habit", "title"]) == attrs.title
      assert get_in(json, ["data", "habit", "user", "id"]) == user_id
    end
  end

  describe "fetching a user's habit" do
    test "returns the habit if owner requests", %{conn: conn, habit: %{id: habit_id}} do
      conn = get conn, Routes.habit_path(conn, :habit, habit_id)
      %{"data" => %{"habit" => %{"id" => id}, "history" => history}} = json_response(conn, 200)

      assert id == habit_id
      assert Enum.all?(history, & ! &1["done"])
      assert 4 == length(history)
    end

    test "returns 404 if habit does not exist", %{conn: conn} do
      conn = get conn, Routes.habit_path(conn, :habit, "unknown")
      assert json_response(conn, 404)
    end

    test "returns the habit if public", %{conn2: conn, user: u} do
      opts = [visibility: "public", start_schedule_process_fn: &start_schedule/1]
      habit = Catena.new_habit("Duo", u, daily_event(), opts)
      conn = get conn, Routes.habit_path(conn, :public_habit, habit.id)
      %{"data" => %{"habit" => %{"id" => id}, "history" => history}} = json_response(conn, 200)

      assert id == habit.id
      assert 4 == length(history)
      assert Enum.all?(history, & ! &1["done"])
    end
  end

  describe "deleting a user's habit" do
    test "succeeds if the owner requests", %{conn: conn, habit: %{id: habit_id}} do
      conn = delete conn, Routes.habit_path(conn, :habit, habit_id)
      assert json_response(conn, 204)
    end

    test "fails if the requester if not owner", %{conn: conn} do
      user = Catena.new_user("another@user.com", "password")
      opts = [visibility: "public", start_schedule_process_fn: &start_schedule/1]
      habit = Catena.new_habit("Duo", user, daily_event(), opts)

      conn = delete conn, Routes.habit_path(conn, :habit, habit.id)
      assert json_response(conn, 404)
    end
  end

  describe "marking a pending habit" do
    test "succeeds if the owner requests", %{conn: conn, user: user} do
      opts = [start_schedule_process_fn: &start_schedule/1]
      habit = Catena.new_habit("Duo", user, daily_event(), opts)
      current_date = NaiveDateTime.to_iso8601(~N[2020-10-22 00:00:00])

      conn = post conn, Routes.habit_path(conn, :mark_pending, habit.id), %{"date" => current_date}
      json = json_response(conn, 200)
      assert json["data"]["habit_id"] == habit.id
    end

    test "fails if the habit is not pending", %{conn: conn, user: user} do
      opts = [start_schedule_process_fn: &start_schedule_without_pending_history/1]
      habit = Catena.new_habit("Duo", user, daily_event(), opts)
      current_date = NaiveDateTime.to_iso8601(~N[2020-10-22 00:00:00])

      conn = post conn, Routes.habit_path(conn, :mark_pending, habit.id), %{"date" => current_date}
      assert json_response(conn, 400)
    end
  end

  describe "updating a habit" do
    test "succeeds if the owner requests", %{conn: conn, habit: %{id: id}} do
      attrs = %{visibility: "public", title: "Premiere habite"}
      conn = put conn, Routes.habit_path(conn, :update, id), attrs
      json = json_response(conn, 200)
      assert get_in(json, ["data", "habit", "visibility"]) == attrs.visibility
      assert get_in(json, ["data", "habit", "title"]) == attrs.title
    end

    test "fails if not requested as the owner", %{conn: conn, habit: habit} do
      user = Catena.new_user("another@user.com", "password")
      attrs = %{visibility: "public", title: "Premiere habite"}
      conn = authenticated_conn(conn, user)
      conn = put conn, Routes.habit_path(conn, :update, habit.id), attrs
      assert json_response(conn, 404)
    end
  end

end
