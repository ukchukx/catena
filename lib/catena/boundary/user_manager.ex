defmodule Catena.Boundary.UserManager do
  alias Catena.Core.{Habit, User}
  alias Catena.Boundary.Utils

  use GenServer

  @supervisor Catena.Supervisor.UserManager
  @registry Catena.Registry.UserManager

  # TODO
  # Schedule an event that runs at the end of the year to reset all schedules

  def active_users do
    @supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.filter(&Utils.child_pid?(&1, __MODULE__))
    |> Enum.flat_map(&Utils.id_from_pid(&1, @registry, __MODULE__))
  end

  def add_habit(id, %Habit{} = habit) do
    with true <- running?(id) do
      id |> via |> GenServer.call({:add_habit, habit})
    else
      false -> :not_running
    end
  end

  def running?(id) do
    active_users()
    |> Enum.any?(fn
      ^id -> true
      _ -> false
    end)
  end

  def stop(id) do
    with true <- running?(id) do
      id |> via |> GenServer.stop()
      # TODO Stop running schedules
    else
      false -> :not_running
    end
  end

  def state(id) do
    with true <- running?(id) do
      id |> via |> GenServer.call(:state)
    else
      false -> :not_running
    end
  end

  def start_user(user = %User{}) do
    DynamicSupervisor.start_child(@supervisor, {__MODULE__, user})
  end

  #
  # Callbacks
  #

  def via(id), do: {:via, Registry, {@registry, id}}

  def child_spec(user = %User{id: id}) do
    %{
      id: {__MODULE__, id},
      start: {__MODULE__, :start_link, [user]},
      restart: :transient
    }
  end

  def start_link(user = %User{id: id}) do
    GenServer.start_link(__MODULE__, user, name: via(id), hibernate_after: 5_000)
  end

  def init(%User{} = user) do
    {:ok, %{user: user, habits: %{}}}
  end

  def init(_), do: {:error, "Only users accepted"}

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_call({:add_habit, habit}, _from, %{habits: habits} = state) do
    Catena.start_schedule_process(habit)

    {:reply, :ok, %{state | habits: Map.put(habits, habit.id, habit)}}
  end
end
