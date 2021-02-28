defmodule Catena.Core.Repeats.Utils do
  @moduledoc false
  alias Catena.Core.{Event, Utils}

  def accumulate_result(next_dates, %Event{repeats: %{until: end_date}} = event, n) do
    case is_nil(end_date) do
      true ->
        {next_dates, {n, %{event | start_date: List.last(next_dates)}}}

      false ->
        next_dates
        |> Enum.filter(&(Utils.earlier?(&1, end_date) or &1 == end_date))
        |> case do
          [] -> nil
          next_dates -> {next_dates, {n, %{event | start_date: List.last(next_dates)}}}
        end
    end
  end

  def accumulate_daily_result(next_date, %Event{repeats: %{until: end_date}} = event, n) do
    case is_nil(end_date) do
      true ->
        {next_date, {n, %{event | start_date: next_date}}}

      false ->
        case Utils.earlier?(next_date, end_date) or next_date == end_date do
          true -> {next_date, {n - 1, %{event | start_date: next_date}}}
          false -> nil
        end
    end
  end
end
