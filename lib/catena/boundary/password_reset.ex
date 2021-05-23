defmodule Catena.Boundary.PasswordReset do
  @moduledoc false

  use GenServer

  def get(email), do: GenServer.call(__MODULE__, {:get, email})

  def put(email, token, ttl_seconds),
    do: GenServer.call(__MODULE__, {:put, email, token, ttl_seconds})

  def delete(email), do: GenServer.call(__MODULE__, {:delete, email})

  #
  # Callbacks
  #

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__, hibernate_after: 5_000)
  end

  def init(state), do: {:ok, state}

  def handle_call({:put, email, token, ttl_seconds}, _from, state) do
    case Map.get(state, email) do
      nil -> :ok
      %{ref: old_ref} -> :erlang.cancel_timer(old_ref)
    end

    record = %{
      token: token,
      created_at: NaiveDateTime.utc_now(),
      ref: schedule_purge(email, ttl_seconds)
    }

    {:reply, record, Map.put(state, email, record)}
  end

  def handle_call({:get, email}, _from, state) do
    record =
      case Map.get(state, email) do
        nil -> nil
        record -> Map.delete(record, :ref)
      end

    {:reply, record, state}
  end

  def handle_call({:delete, email}, _from, state), do: {:reply, :ok, Map.delete(state, email)}

  def handle_info({:purge, email}, state), do: {:noreply, Map.delete(state, email)}

  #
  # Helpers
  #

  defp schedule_purge(email, ttl_seconds) do
    Process.send_after(self(), {:purge, email}, ttl_seconds * 1000)
  end
end
