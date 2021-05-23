defmodule Catena.Core.Repeats.Weekly do
  @moduledoc false

  alias Catena.Core.{Event, Utils}
  alias Catena.Core.Repeats.Utils, as: RepeatUtils
  alias Catena.Core.Repeats.Validators
  # FREQ=WEEKLY;INTERVAL=1;BYDAY=SU;COUNT=5

  @enforce_keys ~w[interval days]a
  defstruct ~w[interval days count until]a

  @type weekday :: :su | :mo | :tu | :we | :th | :fr | :sa
  @type t :: %{
          interval: integer,
          days: [weekday, ...],
          count: nil | integer,
          until: nil | NaiveDateTime.t()
        }

  @spec inflate(binary) :: {:error, any} | t
  @spec new(non_neg_integer(), weekday, keyword) :: {:error, any} | t

  def inflate("FREQ=WEEKLY;" <> str) do
    params = Utils.repetition_string_to_keyword(str)
    new(params[:interval], params[:days], params)
  end

  def inflate(_str), do: {:error, "not a weekly rule"}

  def new(interval, days, opts \\ []) do
    get_optional_params_then_validate_and_create(%{interval: interval, days: days}, opts)
  end

  def adds_start_date?(%Event{start_date: start_date, repeats: %{days: weekdays}}) do
    Utils.weekday(start_date) in Enum.map(weekdays, &weekday_offset/1)
  end

  def next(%__MODULE__{interval: n, days: [day]}, start_date) do
    weekday_of_day = weekday_offset(day)

    next_date =
      case Utils.weekday(start_date) == weekday_of_day do
        true ->
          NaiveDateTime.add(start_date, Utils.days_to_seconds(7 * n))

        false ->
          advance_date_to_next_weekday(start_date, weekday_of_day, n)
      end

    [next_date]
  end

  def next(%__MODULE__{days: days} = rule, start_date) do
    weekdays = Enum.map(days, &weekday_offset/1)
    date_weekday = Utils.weekday(start_date)

    some_index =
      Enum.find_index(weekdays, fn weekday -> weekday > date_weekday end)
      |> case do
        # Falls outside of days, reset to first weekday
        nil -> 0
        some_index -> some_index
      end

    do_next(%{rule | days: weekdays}, start_date, [], some_index) |> Enum.reverse()
  end

  defp do_next(%__MODULE__{days: d}, _date, acc, _idx) when length(d) == length(acc), do: acc

  defp do_next(%__MODULE__{days: weekdays, interval: n} = rule, start_date, acc, current_index) do
    next_current_index = current_index |> Kernel.+(1) |> rem(length(weekdays))
    next_date = advance_date_to_next_weekday(start_date, Enum.at(weekdays, current_index), n)

    do_next(rule, next_date, [next_date | acc], next_current_index)
  end

  def next_occurences(%Event{repeats: %__MODULE__{count: nil}} = event, num),
    do: generate_next_occurences(event, num)

  def next_occurences(%Event{repeats: %__MODULE__{count: num}} = event, _num),
    do: generate_next_occurences(event, num)

  defp generate_next_occurences(%Event{repeats: %__MODULE__{} = rule} = event, num) do
    dates =
      {num, event}
      |> Stream.unfold(fn
        {0, _event} ->
          nil

        {n, event = %{start_date: prev_date}} ->
          rule
          |> next(prev_date)
          |> RepeatUtils.accumulate_result(event, n - 1)
      end)
      |> Enum.to_list()
      |> List.flatten()

    event
    |> adds_start_date?
    |> case do
      false -> dates
      true -> [event.start_date | dates]
    end
    |> Enum.take(num)
  end

  defp get_optional_params_then_validate_and_create(attrs, opts) do
    opts
    |> Keyword.has_key?(:count)
    |> case do
      true -> %{count: Keyword.get(opts, :count)}
      false -> %{until: Keyword.get(opts, :until)}
    end
    |> Map.merge(attrs)
    |> validate_and_create
  end

  defp validate_and_create(%{} = attrs) do
    attrs
    |> Validators.validate([&Validators.validate_day/1])
    |> case do
      :ok -> struct!(__MODULE__, attrs)
      err -> err
    end
  end

  defp advance_date_to_next_weekday(date, target_weekday, interval) do
    weekday_of_date = Utils.weekday(date)

    days_between =
      weekday_of_date
      |> Stream.unfold(fn
        ^target_weekday ->
          nil

        weekday ->
          case weekday == 0 && target_weekday == 7 do
            false -> {1, weekday |> Kernel.+(1) |> rem(7)}
            true -> nil
          end
      end)
      |> Enum.sum()

    seconds = Utils.days_to_seconds(days_between)
    next_date = NaiveDateTime.add(date, seconds)

    seconds =
      case Utils.same_week?(next_date, date) do
        true -> seconds
        false -> seconds + Utils.days_to_seconds(7 * (interval - 1))
      end

    NaiveDateTime.add(date, seconds)
  end

  defp weekday_offset(:su), do: 1
  defp weekday_offset(:mo), do: 2
  defp weekday_offset(:tu), do: 3
  defp weekday_offset(:we), do: 4
  defp weekday_offset(:th), do: 5
  defp weekday_offset(:fr), do: 6
  defp weekday_offset(:sa), do: 7
end
