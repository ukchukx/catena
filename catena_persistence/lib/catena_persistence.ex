defmodule CatenaPersistence do
  @moduledoc false

  alias CatenaPersistence.{Habit, HabitHistory, Repo, User}
  import Ecto.Query, only: [from: 2]

  @spec save_user(struct, function) :: struct
  @spec save_habit_history(struct, function) :: struct
  @spec save_habit(struct, function) :: struct
  @spec users(boolean) :: [map]
  @spec get_user(binary) :: nil | map
  @spec get_user_by_email(binary) :: nil | map
  @spec get_habit(binary) :: nil | map
  @spec get_habit_history(binary) :: nil | map
  @spec user_habits(binary) :: [map]
  @spec habit_history_for_habit(binary) :: [map]
  @spec habit_history_for_user(binary) :: [map]
  @spec delete_habit(struct) :: :ok

  def save_user(user, id_fn) do
    case save(User, User.from_model(user), id_fn) do
      nil -> user
      %{id: id} -> %{user | id: id}
    end
  end

  def save_habit_history(history, id_fn) do
    case save(HabitHistory, HabitHistory.from_model(history), id_fn) do
      nil -> history
      %{id: id} -> %{history | id: id}
    end
  end

  def save_habit(habit, id_fn) do
    case save(Habit, Habit.from_model(habit), id_fn) do
      nil -> habit
      %{id: id} -> %{habit | id: id}
    end
  end

  def users(archived \\ false),
    do: User |> from(where: [archived: ^archived]) |> Repo.all() |> Enum.map(&User.to_map/1)

  def get_user(id) do
    case Repo.get(User, id) do
      nil -> nil
      record -> User.to_map(record)
    end
  end

  def get_user_by_email(email) do
    case Repo.get_by(User, email: email) do
      nil -> nil
      record -> User.to_map(record)
    end
  end

  def get_habit(id) do
    case Repo.get(Habit, id) do
      nil -> nil
      record -> Habit.to_map(record)
    end
  end

  def get_habit_history(id) do
    case Repo.get(HabitHistory, id) do
      nil -> nil
      record -> HabitHistory.to_map(record)
    end
  end

  def user_habits(user_id) do
    Habit
    |> from(where: [user_id: ^user_id])
    |> Repo.all()
    |> Enum.map(&Habit.to_map/1)
  end

  def habit_history_for_habit(habit_id) do
    HabitHistory
    |> from(where: [habit_id: ^habit_id])
    |> Repo.all()
    |> Enum.map(&HabitHistory.to_map/1)
  end

  def habit_history_for_user(user_id) do
    HabitHistory
    |> from(where: [user_id: ^user_id])
    |> Repo.all()
    |> Enum.map(&HabitHistory.to_map/1)
  end

  def delete_habit(%{id: id} = _habit) do
    HabitHistory
    |> from(where: [habit_id: ^id])
    |> Repo.delete_all()

    Habit
    |> from(where: [id: ^id])
    |> Repo.delete_all()

    :ok
  end

  defp save(schema, %{id: id} = model, id_fn) do
    case id do
      nil ->
        %{model | id: id_fn.()}
        |> schema.changeset
        |> Repo.insert()
        |> case do
          {:ok, record} -> record
          _ -> nil
        end

      _ ->
        schema
        |> Repo.get(id)
        |> schema.changeset(model)
        |> Repo.update()
        |> case do
          {:ok, record} -> record
          _ -> nil
        end
    end
  end
end
