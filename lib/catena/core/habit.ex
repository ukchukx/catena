defmodule Catena.Core.Habit do
  alias Catena.Core.{HabitHistory, Event, User, Utils}

  defstruct ~w[user id title description event]a

  @type t :: %{
          id: binary,
          title: String.t(),
          description: String.t(),
          user: User.t(),
          event: Event.t()
        }

  @spec new(String.t(), User.t(), Event.t(), keyword) :: t()
  @spec record_for_date([HabitHistory.t()], NaiveDateTime.t()) :: HabitHistory.t() | nil

  def new(title, user, event, opts \\ []) do
    attrs = %{
      title: title,
      user: user,
      event: event,
      id: Keyword.get(opts, :id, Utils.new_id()),
      description: Keyword.get(opts, :description)
    }

    struct!(__MODULE__, attrs)
  end

  def record_for_date(habit_history, date), do: Enum.find(habit_history, &(&1.date == date))

  def dates(%__MODULE__{event: %Event{repeats: nil} = event}, start_date, end_date) do
    cond do
      Utils.earlier?(event.start_date, start_date) -> []
      Utils.earlier?(end_date, event.start_date) -> []
      true -> [event.start_date]
    end
  end

  def dates(%__MODULE__{event: %Event{} = event}, start_date, end_date) do
    # if event date is later than start date, use event date
    # if event date is earlier than start date, use start date
    # use start date
    start_date =
      case Utils.earlier?(start_date, event.start_date) do
        true ->
          event.start_date

        false ->
          # Unroll event to get the last date <= start_date
          %{event | end_date: start_date} |> unroll() |> List.last()
      end

    end_date =
      cond do
        is_nil(event.end_date) -> end_date
        Utils.earlier?(end_date, event.end_date) -> end_date
        true -> event.end_date
      end

    unroll(%{event | end_date: end_date, start_date: start_date})
  end

  defp unroll(event) do
    event
    |> Stream.unfold(fn
      nil ->
        nil

      event ->
        case Event.next_occurences(event, 380) do
          [] -> nil
          dates -> {dates, %{event | start_date: List.last(dates)}}
        end
    end)
    |> Enum.to_list()
    |> List.flatten()
  end
end
