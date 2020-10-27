defmodule HabitTest do
  use ExUnit.Case, async: true
  use ScheduleBuilders
  use ScheduleAssertions

  @moduletag :habit

  def daily_habit(context) do
    event = daily_event(~N[2020-06-01 00:00:00], 1)
    {:ok, Map.put(context, :habit, new_habit("Daily Habit", [event], "test@user.com"))}
  end

  describe "generating dates for a daily habit" do
    setup [:daily_habit]

    test "when start and end dates are earlier than the habit start date", %{habit: habit} do
      start_date = ~N[2020-05-01 00:00:00]
      end_date = ~N[2020-05-10 00:00:00]

      assert [] = Habit.dates(habit, start_date, end_date)
    end

    test "when start date is earlier than the habit start date", %{habit: habit} do
      %{events: [%{start_date: start_date}]} = habit
      end_date = ~N[2020-06-10 00:00:00]
      [first | _] = dates = Habit.dates(habit, ~N[2020-05-01 00:00:00], end_date)
      [last | _] = Enum.reverse(dates)

      assert 10 == length(dates)
      assert first == start_date
      assert last == end_date
    end

    test "when start date is later than the habit start date", %{habit: habit} do
      start_date = ~N[2020-06-05 00:00:00]
      end_date = ~N[2020-06-10 00:00:00]
      [first | _] = dates = Habit.dates(habit, start_date, end_date)

      assert 6 == length(dates)
      assert first == start_date
      assert [^end_date | _] = Enum.reverse(dates)
    end

    test "when start date is same as the habit start date", %{habit: habit} do
      start_date = ~N[2020-06-01 00:00:00]
      end_date = ~N[2020-06-10 00:00:00]
      [first | _] = dates = Habit.dates(habit, start_date, end_date)

      assert 10 == length(dates)
      assert first == start_date
      assert [^end_date | _] = Enum.reverse(dates)
    end

    test "when end date is earlier than the habit end date", %{habit: habit} do
      %{events: [%{repeats: r} = e]} = habit
      start_date = ~N[2020-06-01 00:00:00]
      end_date = ~N[2020-06-05 00:00:00]
      habit = %{habit | events: [%{e | repeats: %{r | until: ~N[2020-06-10 00:00:00]}}]}
      [first | _] = dates = Habit.dates(habit, start_date, end_date)

      assert 5 == length(dates)
      assert first == start_date
      assert [^end_date | _] = Enum.reverse(dates)
    end
  end

  describe "generating dates for a daily habit with multiple events" do
    setup [:daily_habit]

    test "when start and end dates are earlier than the habit start date", %{habit: habit} do
      %{events: [first_event = %{repeats: repeats}]} = habit
      first_repeats = %{repeats | until: ~N[2020-06-10 00:00:00]}
      second_event = daily_event(~N[2020-06-11 00:00:00], 2)
      habit = %{habit | events: [%{first_event | repeats: first_repeats}, second_event]}
      start_date = ~N[2020-05-01 00:00:00]
      end_date = ~N[2020-05-10 00:00:00]

      assert [] = Habit.dates(habit, start_date, end_date)
    end

    test "when start date is earlier than the habit start date", %{habit: habit} do
      %{events: [first_event = %{start_date: start_date, repeats: repeats}]} = habit
      second_event = daily_event(~N[2020-06-11 00:00:00], 2)
      first_repeats = %{repeats | until: ~N[2020-06-10 00:00:00]}
      habit = %{habit | events: [%{first_event | repeats: first_repeats}, second_event]}
      end_date = ~N[2020-06-19 00:00:00]
      [first | _] = dates = Habit.dates(habit, ~N[2020-05-01 00:00:00], end_date)
      [last | _] = Enum.reverse(dates)

      assert 15 == length(dates)
      assert first == start_date
      assert last == end_date
    end

    test "when start date is later than the habit start date", %{habit: habit} do
      %{events: [first_event = %{repeats: repeats}]} = habit
      first_repeats = %{repeats | until: ~N[2020-06-10 00:00:00]}
      second_event = daily_event(~N[2020-06-11 00:00:00], 2)
      habit = %{habit | events: [%{first_event | repeats: first_repeats}, second_event]}
      start_date = ~N[2020-06-05 00:00:00]
      end_date = ~N[2020-06-19 00:00:00]
      [first | _] = dates = Habit.dates(habit, start_date, end_date)

      assert 11 == length(dates)
      assert first == start_date
      assert [^end_date | _] = Enum.reverse(dates)
    end

    test "when start date is same as the habit start date", %{habit: habit} do
      %{events: [first_event = %{repeats: repeats}]} = habit
      first_repeats = %{repeats | until: ~N[2020-06-10 00:00:00]}
      second_event = daily_event(~N[2020-06-11 00:00:00], 2)
      habit = %{habit | events: [%{first_event | repeats: first_repeats}, second_event]}
      start_date = ~N[2020-06-01 00:00:00]
      end_date = ~N[2020-06-19 00:00:00]
      [first | _] = dates = Habit.dates(habit, start_date, end_date)

      assert 15 == length(dates)
      assert first == start_date
      assert [^end_date | _] = Enum.reverse(dates)
    end

    test "when end date is earlier than the habit end date", %{habit: habit} do
      %{events: [first_event = %{repeats: repeats}]} = habit
      first_repeats = %{repeats | until: ~N[2020-06-10 00:00:00]}
      second_event = daily_event(~N[2020-06-11 00:00:00], 2)
      habit = %{habit | events: [%{first_event | repeats: first_repeats}, second_event]}
      start_date = ~N[2020-06-09 00:00:00]
      end_date = ~N[2020-06-15 00:00:00]
      [first | _] = dates = Habit.dates(habit, start_date, end_date)

      assert 5 == length(dates)
      assert first == start_date
      assert [^end_date | _] = Enum.reverse(dates)
    end
  end

  describe "fetching history for date" do
    setup [:daily_habit]

    test "succeeds when history exists for the supplied date", %{habit: habit} do
      date = ~N[2020-01-02 00:00:00]

      history = [
        new_habit_history(habit, ~N[2020-01-01 00:00:00], true),
        new_habit_history(habit, date, false)
      ]

      assert history_present_for_date?(history, date)
    end

    test "fails when history exists for the supplied date", %{habit: habit} do
      history = [
        new_habit_history(habit, ~N[2020-01-01 00:00:00], true),
        new_habit_history(habit, ~N[2020-01-02 00:00:00], true)
      ]

      refute history_present_for_date?(history, ~N[2020-01-03 00:00:00])
    end
  end
end
