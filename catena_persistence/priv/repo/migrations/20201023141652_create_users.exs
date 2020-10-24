defmodule CatenaPersistence.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :archived, :boolean
      add :username, :string
      add :email, :string
      add :password, :string

      timestamps(type: :utc_datetime)
    end
    create unique_index(:users, [:email])
  end
end
