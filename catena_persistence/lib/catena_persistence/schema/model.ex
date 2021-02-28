defmodule CatenaPersistence.Model do
  @moduledoc false

  @callback to_map(arg :: Ecto.Schema.t()) :: map
  @callback from_model(arg :: struct) :: map
end
