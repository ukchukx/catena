defmodule Catena.Core.HabitHistory do
  @moduledoc false

  alias Catena.Core.Habit

  defstruct ~w[id habit date done]a

  @type t :: %{
          id: binary,
          habit: Habit.t(),
          date: NaiveDateTime.t(),
          done: boolean
        }

  def new(habit, date, opts \\ []) do
    attrs = %{
      habit: habit,
      date: date,
      done: Keyword.get(opts, :done, false),
      id: Keyword.get(opts, :id)
    }

    struct!(__MODULE__, attrs)
  end
end
