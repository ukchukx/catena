defmodule Catena.Boundary.ScheduleManager do
  @moduledoc false

  alias Catena.Boundary.Utils
  alias Catena.Core.{Habit, Schedule}
  use GenServer

  @supervisor Catena.Supervisor.ScheduleManager
  @registry Catena.Registry.ScheduleManager

  def active_schedules do
    @supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.filter(&Utils.child_pid?(&1, __MODULE__))
    |> Enum.flat_map(&Utils.id_from_pid(&1, @registry, __MODULE__))
  end

  def running?(id) do
    active_schedules()
    |> Enum.any?(fn
      ^id -> true
      _ -> false
    end)
  end

  def stop(id) do
    case running?(id) do
      true -> id |> via |> GenServer.stop()
      false -> :not_running
    end
  end

  def state(id) do
    case running?(id) do
      true -> id |> via |> GenServer.call(:state)
      false -> :not_running
    end
  end

  def mark_pending(id, %NaiveDateTime{} = date) do
    case running?(id) do
      true -> id |> via |> GenServer.call({:mark_pending, date})
      false -> :not_running
    end
  end

  def mark_past(id, %NaiveDateTime{} = date) do
    case running?(id) do
      true -> id |> via |> GenServer.call({:mark_past, date})
      false -> :not_running
    end
  end

  def update_habit(id, %{} = params) do
    case running?(id) do
      true -> id |> via |> GenServer.call({:update_habit, params})
      false -> :not_running
    end
  end

  def run_schedule(%Schedule{} = schedule) do
    DynamicSupervisor.start_child(@supervisor, {__MODULE__, schedule})
  end

  #
  # Callbacks
  #

  def via(id), do: {:via, Registry, {@registry, id}}

  def child_spec(%Schedule{habit: %Habit{id: id}} = schedule) do
    %{
      id: {__MODULE__, id},
      start: {__MODULE__, :start_link, [schedule]},
      restart: :transient
    }
  end

  def start_link(%Schedule{habit: %Habit{id: id}} = schedule) do
    GenServer.start_link(__MODULE__, schedule, name: via(id), hibernate_after: 5_000)
  end

  def init(%Schedule{} = schedule) do
    schedule_next_tick()
    {:ok, schedule}
  end

  def init(_), do: {:error, "Only schedules accepted"}

  def handle_call(:state, _from, schedule), do: {:reply, schedule, schedule}

  def handle_call({:mark_past, date}, _from, schedule) do
    {schedule = %{past_events: past}, history} = Schedule.mark_past_event(schedule, date)

    case history do
      nil ->
        {:reply, history, schedule}

      _ ->
        %{id: id} = Catena.save_habit_history(history)
        history = %{history | id: id}
        past = List.replace_at(past, 0, history)

        {:reply, history, %{schedule | past_events: past}}
    end
  end

  def handle_call({:mark_pending, date}, _from, schedule) do
    {schedule = %{past_events: past}, history} = Schedule.mark_pending_event(schedule, date)

    case history do
      nil ->
        {:reply, history, schedule}

      _ ->
        %{id: id} = Catena.save_habit_history(history)
        history = %{history | id: id}
        past = List.replace_at(past, 0, history)

        {:reply, history, %{schedule | past_events: past}}
    end
  end

  def handle_call({:update_habit, params}, _from, %{habit: habit} = schedule) do
    {:reply, :ok, %{schedule | habit: struct(habit, params)}}
  end

  def handle_info(:tick, schedule) do
    schedule_next_tick()

    num_excludes = count_current_event_excludes(schedule)
    %{habit: habit} = schedule = Schedule.update_events(schedule, NaiveDateTime.utc_now())

    case count_current_event_excludes(schedule) do
      ^num_excludes -> :ok
      _increased_num_excludes -> Catena.save_habit(habit)
    end

    {:noreply, schedule}
  end

  defp count_current_event_excludes(%{habit: %{events: events}} = _schedule) do
    events |> List.last() |> Map.get(:excludes) |> length
  end

  defp schedule_next_tick do
    now = NaiveDateTime.utc_now()
    five_minutes_later = NaiveDateTime.add(now, 300)

    Process.send_after(self(), :tick, NaiveDateTime.diff(five_minutes_later, now, :millisecond))
  end
end
