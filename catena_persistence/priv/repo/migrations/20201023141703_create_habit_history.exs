defmodule CatenaPersistence.Repo.Migrations.CreateHabitHistory do
  use Ecto.Migration

  def change do
    create table(:habit_history, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :habit_id, :uuid
      add :user_id, :uuid
      add :date, :naive_datetime

      timestamps(type: :utc_datetime)
    end
    create index(:habit_history, [:habit_id])
    create index(:habit_history, [:user_id])
  end
end
