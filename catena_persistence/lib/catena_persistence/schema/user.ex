defmodule CatenaPersistence.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @behaviour CatenaPersistence.Model
  @primary_key {:id, :binary_id, autogenerate: false}
  @fields ~w[id email username password archived]a

  schema "users" do
    field(:email, :string)
    field(:username, :string)
    field(:password, :string)
    field(:archived, :boolean, default: false)

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
      email: model.email,
      username: model.username,
      password: model.password,
      archived: model.archived
    }
  end

  def to_map(record) do
    %{
      id: record.id,
      email: record.email,
      username: record.username,
      password: record.password,
      archived: record.archived
    }
  end
end
