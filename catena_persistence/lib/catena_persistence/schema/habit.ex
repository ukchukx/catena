defmodule CatenaPersistence.Habit do
  use Ecto.Schema
  import Ecto.Changeset

  @behaviour CatenaPersistence.Model
  @primary_key {:id, :binary_id, autogenerate: false}
  @fields ~w[user_id id title start_date rrule excludes]a

  schema "habits" do
    field :user_id, :binary_id
    field :title, :string
    field :start_date, :naive_datetime
    field :rrule, :string
    field :excludes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(fields), do: changeset(%__MODULE__{}, fields)

  def changeset(%__MODULE__{} = record, fields) do
    record
    |> cast(fields, @fields)
    |> validate_required(@fields -- ~w[excludes]a)
  end

  def from_model(model) do
    %{
      id: model.id,
      user_id: model.user.id,
      title: model.title,
      start_date: model.event.start_date,
      excludes: serialize_excludes(model.event.excludes),
      rrule: serialize_rrule(model.event.repeats)
    }
  end

  def to_map(record) do
    %{
      id: record.id,
      user: record.user_id,
      title: record.title,
      event: %{
        start_date: record.start_date,
        repeats: record.rrule,
        excludes: deserialize_excludes(record.excludes)
      }
    }
  end

  defp serialize_rrule(nil), do: nil
  defp serialize_rrule(event), do: to_string(event)

  defp serialize_excludes([]), do: nil
  defp serialize_excludes(excludes) do
    excludes
    |> Enum.map(&NaiveDateTime.to_iso8601/1)
    |> Enum.join(",")
  end

  defp deserialize_excludes(nil), do: []
  defp deserialize_excludes(excludes) do
    excludes
    |> String.split(",", trim: true)
    |> Enum.map(&NaiveDateTime.from_iso8601/1)
  end
end
