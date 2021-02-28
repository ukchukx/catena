defmodule ScheduleAssertions do
  defmacro __using__(_options) do
    quote do
      import ScheduleAssertions, only: :functions
    end
  end

  alias Catena.Core.{Habit, HabitHistory}

  def days_apart?(date_after, date_before, days) do
    date_after |> NaiveDateTime.diff(date_before) |> div(86_400) |> Kernel.==(days)
  end

  def months_apart?(%{month: m1} = _earlier, %{month: m2} = _later, months),
    do: rem(m1 + months, 12) == m2

  def years_apart?(%{year: y1} = _earlier, %{year: y2} = _later, years), do: y2 - y1 == years

  def years_apart?(_earlier, _later, _years), do: false

  def history_present_for_date?(history, date) do
    case Habit.history_for_date(history, date) do
      %HabitHistory{date: ^date} -> true
      _ -> false
    end
  end
end
