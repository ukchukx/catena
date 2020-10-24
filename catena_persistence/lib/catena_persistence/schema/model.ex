defmodule CatenaPersistence.Model do
  @callback to_map(arg :: Ecto.Schema.t) :: map
  @callback from_model(arg :: struct) :: map
end
