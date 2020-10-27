defmodule ScheduleTest do
  use ExUnit.Case, async: true
  use ScheduleBuilders
  use ScheduleAssertions

  @moduletag :schedule

  def daily_habit(context) do
    event = daily_event(~N[2020-10-21 00:00:00], 1)
    {:ok, Map.put(context, :habit, new_habit("Daily Habit", [event], "test@user.com"))}
  end

  describe "creating a schedule" do
    setup [:daily_habit]

    test "puts current_date events in future events if not done", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      past_event_dates = [~N[2020-10-21 00:00:00]]
      future_event_dates = [current_date, ~N[2020-10-23 00:00:00]]
      schedule = new_schedule(habit, [], start_date, end_date, current_date)

      assert past_event_dates == schedule.past_events |> Enum.map(& &1.date) |> Enum.reverse()
      assert future_event_dates == Enum.map(schedule.future_events, & &1.date)
    end

    test "puts done events on current_date in past events", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      past_event_dates = [~N[2020-10-21 00:00:00], current_date]
      future_event_dates = [~N[2020-10-23 00:00:00]]
      habit_history = [new_habit_history(habit, current_date, true)]
      schedule = new_schedule(habit, habit_history, start_date, end_date, current_date)

      assert past_event_dates == schedule.past_events |> Enum.map(& &1.date) |> Enum.reverse()
      assert future_event_dates == Enum.map(schedule.future_events, & &1.date)
    end
  end

  describe "testing pending schedules" do
    setup [:daily_habit]

    test "returns true if schedule is pending", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      schedule = new_schedule(habit, [], start_date, end_date, current_date)

      assert Schedule.pending?(schedule, current_date)
    end

    test "returns false if schedule is not pending", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      habit_history = [new_habit_history(habit, current_date, true)]
      schedule = new_schedule(habit, habit_history, start_date, end_date, current_date)

      refute Schedule.pending?(schedule, current_date)
    end
  end

  describe "marking pending schedules" do
    setup [:daily_habit]

    test "succeeds if schedule is pending", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      schedule = new_schedule(habit, [], start_date, end_date, current_date)

      assert {_schedule, %HabitHistory{done: true, date: ^current_date}} =
               Schedule.mark_pending_event(schedule, current_date)
    end

    test "fails if schedule is not pending", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      habit_history = [new_habit_history(habit, current_date, true)]
      schedule = new_schedule(habit, habit_history, start_date, end_date, current_date)

      assert {^schedule, nil} = Schedule.mark_pending_event(schedule, current_date)
    end
  end

  describe "marking past schedules" do
    setup [:daily_habit]

    test "succeeds if event is in the past and not done", %{habit: habit = %{events: [event]}} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      past_date = event.start_date
      schedule = new_schedule(habit, [], start_date, end_date, current_date)

      assert {_schedule, %HabitHistory{date: ^past_date, done: true}} =
               Schedule.mark_past_event(schedule, past_date)
    end

    test "fails if event does not exist", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      habit_history = [new_habit_history(habit, current_date, true)]
      past_date = ~N[2020-09-01 00:00:00]
      schedule = new_schedule(habit, habit_history, start_date, end_date, current_date)

      assert {^schedule, nil} = Schedule.mark_past_event(schedule, past_date)
    end

    test "fails if event exists but is done", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      habit_history = [new_habit_history(habit, current_date, true)]
      schedule = new_schedule(habit, habit_history, start_date, end_date, current_date)

      assert {^schedule, nil} = Schedule.mark_past_event(schedule, current_date)
    end
  end

  describe "updating schedule events" do
    setup [:daily_habit]

    test "moves past future events into past_events", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      schedule = new_schedule(habit, [], start_date, end_date, current_date)
      past_events = [~N[2020-10-21 00:00:00]]
      future_events = [current_date, end_date]

      assert past_events == schedule.past_events |> Enum.map(& &1.date) |> Enum.reverse()
      assert future_events == Enum.map(schedule.future_events, & &1.date)

      %{past_events: past, future_events: future} = Schedule.update_events(schedule, end_date)

      assert [~N[2020-10-21 00:00:00], current_date] == Enum.reverse(Enum.map(past, & &1.date))
      assert [end_date] == Enum.map(future, & &1.date)
    end

    test "moves past future events into excludes if habit is archived", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      past_events = [~N[2020-10-21 00:00:00]]
      schedule = new_schedule(%{habit | archived: true}, [], start_date, end_date, current_date)
      %{habit: %{events: [event]}, past_events: past} = Schedule.update_events(schedule, end_date)

      assert [current_date] == event.excludes
      assert past_events == Enum.map(past, & &1.date)
    end

    test "does nothing if there are no future events", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      schedule = new_schedule(habit, [], start_date, end_date, current_date)
      schedule = Schedule.update_events(%{schedule | future_events: []}, current_date)

      assert [] = schedule.future_events
    end

    test "does nothing if no future events are past", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      habit_history = [new_habit_history(habit, current_date, true)]
      schedule = new_schedule(habit, habit_history, start_date, end_date, current_date)
      past_events = schedule.past_events
      future_events = schedule.future_events
      schedule = Schedule.update_events(schedule, current_date)

      assert schedule.future_events == future_events
      assert schedule.past_events == past_events
    end

    test "moves done future events into the past", %{habit: habit} do
      start_date = ~N[2020-10-01 00:00:00]
      end_date = ~N[2020-10-23 00:00:00]
      current_date = ~N[2020-10-22 00:00:00]
      habit_history = [new_habit_history(habit, current_date, true)]
      schedule = new_schedule(habit, habit_history, start_date, end_date, current_date)
      future_events = Enum.map(schedule.future_events, &%{&1 | done: true})

      schedule = Schedule.update_events(%{schedule | future_events: future_events}, current_date)

      assert [] = schedule.future_events
    end
  end
end
