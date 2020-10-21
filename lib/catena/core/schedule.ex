defmodule Catena.Core.Schedule do
  alias Catena.Core.{Habit, HabitHistory, Utils}

  @enforce_keys ~w[habit]a
  defstruct habit: nil, past_events: [], future_events: []

  @type t :: %{
          habit: Habit.t(),
          past_events: [HabitHistory.t()],
          future_events: [HabitHistory.t()]
        }

  @spec new(
          Habit.t(),
          [HabitHistory.t()],
          NaiveDateTime.t(),
          NaiveDateTime.t(),
          NaiveDateTime.t()
        ) :: t()
  @spec pending?(t(), NaiveDateTime.t()) :: boolean
  @spec tick(t(), NaiveDateTime.t()) :: t()
  @spec mark_pending_event(t(), NaiveDateTime.t()) :: t()

  def new(habit, done, start_date, end_date, current_date) do
    {past_events, future_events} =
      habit
      |> Habit.dates(start_date, end_date)
      |> Enum.map(fn date ->
        case Habit.record_for_date(done, date) do
          nil -> HabitHistory.new(habit, date, done?: false)
          habit_history -> habit_history
        end
      end)
      |> Enum.split_with(&(Utils.earlier?(&1.date, current_date) or &1.done?))

    # Store past events in reverse order for faster insertions and for
    # faster retrieval of the latest past event
    attrs = %{
      habit: habit,
      past_events: Enum.reverse(past_events),
      future_events: future_events
    }

    struct!(__MODULE__, attrs)
  end

  def pending?(%__MODULE__{future_events: []}, _date), do: false

  def pending?(%__MODULE__{future_events: [%HabitHistory{date: d} | _]}, date) do
    %{year: y1, month: m1, day: d1} = date
    %{year: y2, month: m2, day: d2} = d

    y1 == y2 and m1 == m2 and d1 == d2
  end

  def tick(%__MODULE__{future_events: events, past_events: past_events} = mod, date) do
    {past, future} = Enum.split_with(events, &Utils.earlier?(&1, date))
    %{mod | past_events: transfer_head_items(past, past_events), future_events: future}
  end

  def mark_pending_event(%__MODULE__{future_events: []} = mod, _date), do: mod

  def mark_pending_event(%__MODULE__{} = mod, date) do
    %{future_events: [first | rest], past_events: past} = mod

    case pending?(mod, date) do
      true -> %{mod | past_events: [%{first | done?: true} | past], future_events: rest}
      false -> mod
    end
  end

  defp transfer_head_items([], list), do: list

  defp transfer_head_items([head | rest], list), do: transfer_head_items(rest, [head | list])
end
