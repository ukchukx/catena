defmodule Catena.Core.Habit do
  @moduledoc false

  alias Catena.Core.{Event, HabitHistory, User, Utils}

  defstruct ~w[user id title events visibility archived]a

  @type t :: %{
          id: binary,
          title: String.t(),
          visibility: String.t(),
          user: User.t(),
          archived: boolean,
          events: [Event.t()]
        }

  @spec history_for_date([HabitHistory.t()], NaiveDateTime.t()) :: HabitHistory.t() | nil

  def new(title, user, events, opts \\ []) do
    attrs = %{
      title: title,
      user: user,
      events: events,
      id: Keyword.get(opts, :id),
      visibility: Keyword.get(opts, :visibility, "private"),
      archived: Keyword.get(opts, :archived, false)
    }

    struct!(__MODULE__, attrs)
  end

  def history_for_date(habit_history, date) do
    %{year: y, month: m, day: d} = date

    Enum.find(habit_history, fn
      %{date: %{year: ^y, month: ^m, day: ^d}} -> true
      _ -> false
    end)
  end

  def dates(%__MODULE__{events: events}, start_date, end_date) do
    events
    |> Enum.map(&generate_dates(&1, start_date, end_date))
    |> List.flatten()
    |> Enum.sort(&(Utils.earlier?(&1, &2) or Utils.same_day?(&1, &2)))
  end

  defp generate_dates(%Event{repeats: nil} = event, start_date, end_date) do
    cond do
      Utils.earlier?(event.start_date, start_date) -> []
      Utils.earlier?(end_date, event.start_date) -> []
      true -> [event.start_date]
    end
  end

  defp generate_dates(%Event{repeats: repeats} = event, start_date, end_date) do
    # if event date is later than start date, use event date
    # if event date is earlier than start date, use start date
    # use start date
    start_date =
      start_date
      |> Utils.earlier?(event.start_date)
      |> Kernel.or(Utils.same_day?(start_date, event.start_date))
      |> case do
        true ->
          event.start_date

        false ->
          # Unroll event to get the last date <= start_date
          %{event | repeats: %{repeats | until: start_date}}
          |> unroll()
          |> case do
            [] -> start_date
            list -> List.last(list)
          end
      end

    end_date = select_end_date(end_date, repeats.until)

    case Utils.earlier?(end_date, start_date) do
      true -> []
      false -> unroll(%{event | repeats: %{repeats | until: end_date}, start_date: start_date})
    end
  end

  defp select_end_date(end_date, until) do
    cond do
      is_nil(until) -> end_date
      Utils.earlier?(end_date, until) -> end_date
      true -> until
    end
  end

  defp unroll(event = %{repeats: %{count: x, until: end_date}}) when is_integer(x) do
    event
    |> Stream.unfold(fn
      nil ->
        nil

      event ->
        case Event.next_occurences(event, x) do
          [] -> nil
          [date] -> {[date], nil}
          dates -> {dates, nil}
        end
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.filter(fn dt -> Utils.earlier?(dt, end_date) or Utils.same_day?(dt, end_date) end)
    |> Enum.uniq()
  end

  defp unroll(event) do
    event
    |> Stream.unfold(fn
      nil ->
        nil

      event ->
        case Event.next_occurences(event, 380) do
          [] -> nil
          [date] -> {[date], nil}
          dates -> {dates, %{event | start_date: List.last(dates)}}
        end
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.uniq()
  end
end
