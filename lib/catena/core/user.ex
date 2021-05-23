defmodule Catena.Core.User do
  @moduledoc false

  defstruct [:id, :username, :email, :password, archived: false]

  @type t :: %{
          id: binary,
          username: String.t(),
          email: String.t(),
          password: String.t(),
          archived: boolean
        }

  def new(email, opts \\ []) do
    attrs = %{
      email: email,
      id: Keyword.get(opts, :id),
      username: Keyword.get(opts, :username, email),
      password: Keyword.get(opts, :password),
      archived: Keyword.get(opts, :archived, false)
    }

    struct!(__MODULE__, attrs)
  end
end
