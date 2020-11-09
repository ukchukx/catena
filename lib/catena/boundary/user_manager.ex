defmodule Catena.Boundary.UserManager do
  alias Catena.Core.{Habit, User}
  alias Catena.Boundary.{ScheduleManager, Utils}

  use GenServer

  @supervisor Catena.Supervisor.UserManager
  @registry Catena.Registry.UserManager

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

  def remove_habit(id, %Habit{} = habit) do
    with true <- running?(id) do
      id |> via |> GenServer.call({:remove_habit, habit})
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
    with %{habits: habits} <- state(id) do
      Enum.each(habits, &ScheduleManager.stop/1)

      id |> via |> GenServer.stop()
    else
      _ -> :not_running
    end
  end

  def state(id) do
    with true <- running?(id) do
      id |> via |> GenServer.call(:state)
    else
      false -> :not_running
    end
  end

  def update(id, params) do
    with true <- running?(id) do
      id |> via |> GenServer.call({:update, params})
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
    schedule_next_tick()
    {:ok, %{user: user, habits: []}}
  end

  def init(_), do: {:error, "Only users accepted"}

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_call({:add_habit, %{id: id} = _habit}, _from, %{habits: habits} = state) do
    {:reply, :ok, %{state | habits: [id | habits]}}
  end

  def handle_call({:remove_habit, %{id: id} = _habit}, _from, %{habits: habits} = state) do
    {:reply, :ok, %{state | habits: Enum.filter(habits, &(&1 != id))}}
  end

  def handle_call({:update, params}, _from, %{user: user} = state) do
    user = struct(user, params)

    {:reply, user, %{state | user: user}}
  end

  def handle_info(:new_year, %{user: user, habits: habits} = state) do
    schedule_next_tick()
    Catena.restart_user_schedules(user, habits)
    {:noreply, state}
  end

  defp schedule_next_tick do
    now = NaiveDateTime.utc_now()
    next_new_year = NaiveDateTime.new!(now.year + 1, 1, 1, 0, 0, 0)

    Process.send_after(self(), :new_year, NaiveDateTime.diff(next_new_year, now, :millisecond))
  end
end
