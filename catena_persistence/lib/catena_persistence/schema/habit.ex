defmodule CatenaPersistence.Habit do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @behaviour CatenaPersistence.Model
  @primary_key {:id, :binary_id, autogenerate: false}
  @fields ~w[user_id id title events visibility archived]a

  schema "habits" do
    field(:user_id, :binary_id)
    field(:title, :string)
    field(:visibility, :string)
    field(:archived, :boolean)
    field(:events, :map)

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
      visibility: model.visibility,
      archived: model.archived,
      events: %{data: Enum.map(model.events, &from_event/1)}
    }
  end

  def to_map(record) do
    %{
      id: record.id,
      user: record.user_id,
      title: record.title,
      visibility: record.visibility,
      archived: record.archived,
      events: Enum.map(record.events["data"], &to_event/1)
    }
  end

  defp from_event(event) do
    %{
      start_date: NaiveDateTime.to_iso8601(event.start_date),
      repeats: serialize_repeats(event.repeats),
      excludes: serialize_excludes(event.excludes)
    }
  end

  defp to_event(event_record) do
    %{
      start_date: NaiveDateTime.from_iso8601!(event_record["start_date"]),
      repeats: event_record["repeats"],
      excludes: deserialize_excludes(event_record["excludes"])
    }
  end

  defp serialize_repeats(nil), do: nil
  defp serialize_repeats(event), do: to_string(event)

  def serialize_excludes([]), do: nil

  def serialize_excludes(excludes) do
    excludes
    |> Enum.map(&NaiveDateTime.to_iso8601/1)
    |> Enum.join(",")
  end

  def deserialize_excludes(nil), do: []

  def deserialize_excludes(excludes) do
    excludes
    |> String.split(",", trim: true)
    |> Enum.map(&NaiveDateTime.from_iso8601/1)
  end
end
