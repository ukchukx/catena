defmodule CatenaPersistence.HabitHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @behaviour CatenaPersistence.Model
  @primary_key {:id, :binary_id, autogenerate: false}
  @fields ~w[id date habit_id user_id]a

  schema "habit_history" do
    field :date, :naive_datetime
    field :user_id, :binary_id
    field :habit_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(fields), do: changeset(%__MODULE__{}, fields)

  def changeset(%__MODULE__{} = record, fields) do
    record
    |> cast(fields, @fields)
    |> validate_required(@fields)
  end

  def from_model(model) do
    %{
      id: model.id,
      habit_id: model.habit.id,
      user_id: model.habit.user.id,
      date: model.date
    }
  end

  def to_map(record) do
    %{
      id: record.id,
      habit: record.habit_id,
      user: record.user_id,
      date: record.date
    }
  end
end
