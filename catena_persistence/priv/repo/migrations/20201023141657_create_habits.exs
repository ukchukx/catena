defmodule CatenaPersistence.Repo.Migrations.CreateHabits do
  use Ecto.Migration

  def change do
    create table(:habits, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, :uuid
      add :title, :string
      add :visibility, :string
      add :archived, :boolean
      add :events, :map # [{excludes, repeats, start_date}]

      timestamps(type: :utc_datetime)
    end
    create index(:habits, [:user_id])
  end
end
