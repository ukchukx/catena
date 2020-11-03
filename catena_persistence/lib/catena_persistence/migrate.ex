defmodule CatenaPersistence.Migrate do
  require Logger

  def run do
     Logger.info("Running migrations...")
     path = Application.app_dir(:catena_persistence, "priv/repo/migrations")
     Ecto.Migrator.run(CatenaPersistence.Repo, path, :up, all: true)
     Logger.info("Done running migrations")
  end

end
