defmodule Catena.Core.User do
  alias Catena.Core.Utils

  @enforce_keys ~w[email]a
  defstruct [:id, :username, :email, :password, archived?: false]

  @type t :: %{
          id: binary,
          username: String.t(),
          email: String.t(),
          password: String.t(),
          archived?: boolean
        }

  def new(email, opts \\ []) do
    attrs = %{
      email: email,
      id: Keyword.get(opts, :id, Utils.new_id()),
      username: Keyword.get(opts, :username, email),
      password: Keyword.get(opts, :password),
      archived?: Keyword.get(opts, :archived?, false)
    }

    struct!(__MODULE__, attrs)
  end
end
