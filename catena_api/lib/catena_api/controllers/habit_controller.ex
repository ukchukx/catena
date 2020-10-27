defmodule CatenaApi.HabitController do
  alias Catena.Core.Event

  use CatenaApi, :controller
  require Logger

  def habits(%{assigns: %{user: %{id: id}}} = conn, _params) do
    user = Catena.get_user(id: id)
    habits = id |> Catena.get_habits() |> Enum.map(&CatenaApi.Utils.schedule_to_map(&1, user))
    json(conn, %{success: true, data: habits})
  end

  defdelegate public_habit(conn, params), to: __MODULE__, as: :habit

  def habit(%{assigns: %{user: %{id: user_id, email: email}}} = conn, %{"id" => id}) do
    with %{habit: habit} = schedule <- Catena.get_habit(id),
        true <- habit.user.id == user_id or habit.visibility == "public",
        user <- Catena.get_user(id: habit.user.id) do
      json(conn, %{success: true, data: CatenaApi.Utils.schedule_to_map(schedule, user)})
    else
      false ->
        Logger.warn("'#{email}' cannot access habit '#{id}': not owner and habit is private")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})

      nil ->
        Logger.warn("Could not find habit '#{id}'")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})
    end
  end

  def habit(conn, %{"id" => id}) do
    with %{habit: habit = %{user: %{id: user_id}}} = schedule <- Catena.get_habit(id),
        true <- habit.visibility == "public",
        user <- Catena.get_user(id: user_id),
        schedule <- CatenaApi.Utils.schedule_to_map(schedule, user) do
      json(conn, %{success: true, data: schedule})
    else
      false ->
        Logger.error("Cannot access habit '#{id}' habit is private")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})

      nil ->
        Logger.warn("Could not find habit '#{id}'")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})
    end
  end

  def create(%{assigns: %{user: %{id: id, email: email}}} = conn, %{"title" => title} = params) do
    title = to_string(title)

    with %{"start_date" => start_date} <- params,
        viz <- Map.get(params, "visibility", "private"),
        excludes <- params |> Map.get("excludes", []) |> Enum.map(&NaiveDateTime.from_iso8601/1),
        repetition <- params |> Map.get("repeats") |> Event.inflate_repetition(),
        start_date <- NaiveDateTime.from_iso8601!(start_date),
        event <- Event.new(start_date, [repeats: repetition, excludes: excludes]),
        user <- Catena.get_user(id: id),
        %{id: handle_id} <- Catena.new_habit(title, user, [event], [visibility: viz]),
        schedule <- Catena.get_habit(handle_id) do
      Logger.info("Habit '#{title}' for '#{email}' created")

      conn
      |> put_status(201)
      |> json(%{success: true, data: CatenaApi.Utils.schedule_to_map(schedule, user)})
    else
      err when is_list(err) ->
        err = CatenaApi.Utils.merge_errors(err)
        Logger.error("Could not create habit for '#{email}': #{inspect err}")

        conn
        |> put_status(422)
        |> json(%{success: false, errors: err, message: "Validation failed"})

      err ->
        Logger.error("Could not create habit '#{title}' for '#{email}': #{inspect err}")

        conn
        |> put_status(400)
        |> json(%{success: false})
    end
  end

  def update(%{assigns: %{user: %{id: user_id, email: email}}} = conn, %{"id" => id} = params) do
    with %{habit: habit = %{title: t, visibility: v}} <- Catena.get_habit(id),
         true <- habit.user.id == user_id,
         t <- Map.get(params, "title", t) |> to_string,
         v <- Map.get(params, "visibility", v),
         a <- Map.get(params, "archived", habit.archived),
         _habit <- Catena.update_habit(id, %{title: t, visibility: v, archived: a}),
         user <- Catena.get_user(id: user_id),
         schedule <- id |> Catena.get_habit() |> CatenaApi.Utils.schedule_to_map(user) do
      Logger.info("Habit '#{id}' updated")
      json(conn, %{success: true, data: schedule})
    else
      false ->
        Logger.warn("Cannot update habit '#{id}': '#{email}' is not owner")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})

      nil ->
        Logger.warn("Could not find habit '#{id}'")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})
    end
  end

  def change_schedule(%{assigns: %{user: %{id: user_id, email: email}}} = conn, params) do
    %{"id" => id} = params
    default_date = NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()
    last_until_str = Map.get(params, "last_until", default_date)
    last_until = NaiveDateTime.from_iso8601!(last_until_str)
    start_date = Map.get(params, "start_date", last_until_str) |> NaiveDateTime.from_iso8601!()
    excludes = params |> Map.get("excludes", []) |> Enum.map(&NaiveDateTime.from_iso8601/1)
    repeats =  Map.get(params, "repeats")
    event_params = %{repeats: repeats, excludes: excludes, start_date: start_date}

    with %{habit: habit} <- Catena.get_habit(id),
         true <- habit.user.id == user_id,
         _habit <- Catena.add_event(id, event_params, last_until),
         schedule <- Catena.get_habit(id),
         user <- Catena.get_user(id: user_id),
         schedule <- CatenaApi.Utils.schedule_to_map(schedule, user) do
      Logger.info("Schedule for habit '#{id}' updated")

      json(conn, %{success: true, data: schedule})
    else
      false ->
        Logger.warn("Cannot update schedule for habit '#{id}': '#{email}' is not owner")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})

      nil ->
        Logger.warn("Could not find habit '#{id}'")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})
    end
  end

  def delete(%{assigns: %{user: %{id: user_id, email: email}}} = conn, %{"id" => id}) do
    with %{habit: habit} <- Catena.get_habit(id),
        true <- habit.user.id == user_id  do
      Catena.delete_habit(id)

      conn
      |> put_status(204)
      |> json(%{success: true})
    else
      false ->
        Logger.warn("Cannot delete habit '#{id}': '#{email}' is not owner")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})

      nil ->
        Logger.warn("Could not find habit '#{id}'")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})
    end
  end

  def mark_pending(%{assigns: %{user: %{id: user_id} = user}} = conn, %{"id" => id} = params) do
    with %{habit: habit} <- Catena.get_habit(id),
         default_date <- NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601(),
         date <- Map.get(params, "date", default_date) |> NaiveDateTime.from_iso8601!(),
         true <- habit.user.id == user_id  do
      case Catena.mark_pending_habit(id, date) do
        nil ->
          Logger.warn("Cannot mark habit '#{id}': not pending")

          conn
          |> put_status(400)
          |> json(%{success: false, message: "Habits can only be marked on their due date"})

        history ->
          Logger.info("Habit '#{id}' marked on #{date}")
          history = CatenaApi.Utils.habit_history_to_map(history)

          conn
          |> put_status(200)
          |> json(%{success: true, data: history})
      end
    else
      false ->
        Logger.warn("Cannot mark pending habit '#{id}': '#{user.email}' is not owner")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})

      nil ->
        Logger.warn("Could not find habit '#{id}'")

        conn
        |> put_status(404)
        |> json(%{success: false, message: "Not found"})
    end
  end
end
