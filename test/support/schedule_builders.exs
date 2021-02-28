defmodule ScheduleBuilders do
  defmacro __using__(_options) do
    quote do
      alias Catena.Core.{Event, Habit, HabitHistory, Schedule, User}
      alias Catena.Core.Repeats.{Daily, Monthly, Weekly, Yearly}

      import ScheduleBuilders, only: :functions
    end
  end

  alias Catena.Core.{Event, Habit, HabitHistory, Schedule, User}
  alias Catena.Core.Repeats.{Daily, Monthly, Weekly, Yearly}

  def daily_event(start_date, interval),
    do: Event.new(start_date, repeats: Daily.new(interval))

  def weekly_event(start_date, interval, days) do
    Event.new(start_date, repeats: Weekly.new(interval, days))
  end

  def monthly_event(start_date, interval, days) do
    Event.new(start_date, repeats: Monthly.new(interval, monthdays: days))
  end

  def yearly_event(start_date, interval, month, days) do
    Event.new(start_date, repeats: Yearly.new(interval, month, monthdays: days))
  end

  def one_time_event(start_date), do: Event.new(start_date)

  def new_user(email), do: User.new(email)

  def new_habit(title, event, email \\ "test@user.com"),
    do: Habit.new(title, new_user(email), event)

  def new_habit_history(habit, date, done), do: HabitHistory.new(habit, date, done: done)

  def new_schedule(habit, habit_history, start_date, end_date, current_date) do
    Schedule.new(habit, habit_history, start_date, end_date, current_date)
  end
end
