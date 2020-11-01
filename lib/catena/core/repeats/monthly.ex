defmodule Catena.Core.Repeats.Monthly do
  alias Catena.Core.Repeats.Validators
  alias Catena.Core.{Event, Utils}
  # FREQ=MONTHLY;INTERVAL=1;BYDAY=1SU,1TU;COUNT=5 - month by day
  # FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=1,2;COUNT=5 - month by date

  # TODO
  # Implement for days > 28
  # Implement byday
  # Test bydays: test 1 day in month, multiple days in month

  @type day :: 1..31
  @type ordday ::
          :"1su"
          | :"2su"
          | :"3su"
          | :"4su"
          | :"-1su"
          | :"1mo"
          | :"2mo"
          | :"3mo"
          | :"4mo"
          | :"-1mo"
          | :"1tu"
          | :"2tu"
          | :"3tu"
          | :"4tu"
          | :"-1tu"
          | :"1we"
          | :"2we"
          | :"3we"
          | :"4we"
          | :"-1we"
          | :"1th"
          | :"2th"
          | :"3th"
          | :"4th"
          | :"-1th"
          | :"1fr"
          | :"2fr"
          | :"3fr"
          | :"4fr"
          | :"-1fr"
          | :"1sa"
          | :"2sa"
          | :"3sa"
          | :"4sa"
          | :"-1sa"

  @type t :: %{
          interval: integer,
          days: nil | [ordday, ...],
          monthdays: nil | [day, ...],
          count: nil | integer,
          until: nil | NaiveDateTime.t()
        }
  @enforce_keys ~w[interval]a
  defstruct ~w[interval days monthdays count until]a

  @spec inflate(binary) :: {:error, any} | t
  @spec new(non_neg_integer(), keyword) :: {:error, any} | t
  @spec next(t(), NaiveDateTime.t()) :: [NaiveDateTime.t()]
  @spec next_occurences(Event.t(), non_neg_integer()) :: [NaiveDateTime.t()]

  def inflate("FREQ=MONTHLY;" <> str) do
    params = Utils.repetition_string_to_keyword(str)
    new(params[:interval], params)
  end

  def inflate(_str), do: {:error, "not a monthly rule"}

  def new(interval, opts \\ []) do
    opts
    |> Keyword.has_key?(:monthdays)
    |> case do
      false -> %{days: Keyword.get(opts, :days)}
      true -> %{monthdays: Keyword.get(opts, :monthdays)}
    end
    |> Map.put(:interval, interval)
    |> get_optional_params_validate_and_create(opts)
  end

  def next(%__MODULE__{interval: n, monthdays: [day]}, from_date) when is_integer(day) do
    [advance_date_to_next_monthday(from_date, day, n)]
  end

  def next(%__MODULE__{monthdays: [day | _] = days} = rule, from_date) when is_integer(day) do
    %{day: date_day} = from_date

    day_index =
      Enum.find_index(days, fn day -> day > date_day end)
      |> case do
        # Falls outside of days, reset to first day
        nil -> 0
        day_index -> day_index
      end

    do_next(rule, from_date, [], day_index) |> Enum.reverse()
  end

  def next_occurences(%Event{repeats: %__MODULE__{count: nil}} = event, num),
    do: generate_next_occurences(event, num)

  def next_occurences(%Event{repeats: %__MODULE__{count: num}} = event, _num),
    do: generate_next_occurences(event, num)

  defp generate_next_occurences(%Event{repeats: %__MODULE__{until: end_date} = rule} = event, num) do
    {num, event}
    |> Stream.unfold(fn
      {0, _event} ->
        nil

      {n, event = %{start_date: prev_date}} ->
        next_dates = next(rule, prev_date)

        with true <- is_nil(end_date) do
          {next_dates, {n - 1, %{event | start_date: List.last(next_dates)}}}
        else
          false ->
            next_dates =
              Enum.filter(next_dates, &(Utils.earlier?(&1, end_date) or &1 == end_date))

            case next_dates do
              [] -> nil
              _ -> {next_dates, {n - 1, %{event | start_date: List.last(next_dates)}}}
            end
        end
    end)
    |> Enum.to_list()
    |> List.flatten()
  end

  defp do_next(%__MODULE__{monthdays: d}, _date, acc, _idx) when length(d) == length(acc), do: acc

  defp do_next(%__MODULE__{monthdays: days, interval: n} = rule, start_date, acc, current_index) do
    next_current_index = current_index |> Kernel.+(1) |> rem(length(days))
    next_date = advance_date_to_next_monthday(start_date, Enum.at(days, current_index), n)

    do_next(rule, next_date, [next_date | acc], next_current_index)
  end

  defp get_optional_params_validate_and_create(attrs, opts) do
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
    |> Validators.validate([&Validators.validate_day_or_monthday/1])
    |> case do
      :ok -> struct!(__MODULE__, attrs)
      err -> err
    end
  end

  defp advance_date_to_next_monthday(date, target_day, interval) do
    %{day: day} = date

    case day < target_day do
      true ->
        Utils.advance_date_by_days(date, target_day - day)

      false ->
        %{month: month} = new_date = maybe_skip_unwanted_months(date, target_day)

        # If we've already added a month, decrement here using the -1
        months_to_add =
          date
          |> Utils.same_month?(new_date)
          |> case do
            true -> interval + month
            false -> interval + month - 1
          end
          |> Kernel.-(month)

        new_date
        |> Utils.advance_date_by_months(months_to_add)
        |> normalize_month()
    end
  end

  defp normalize_month(%{day: day} = date) do
    # If day is > than days in month, increment month until we get to a valid date
    date
    |> Date.days_in_month()
    |> Kernel.<(day)
    |> case do
      true -> date |> Utils.advance_date_by_months(1) |> normalize_month()
      false -> date
    end
  end

  defp maybe_skip_unwanted_months(date, target_day) do
    # Skip over Feb if target_date is > 28 in non-leap years or > 29 in leap years
    end_of_month = %{date | day: Date.days_in_month(date)}
    days_to_ignore = days_to_skip(end_of_month)
    days_to_add =
      cond do
        days_to_ignore == 0 -> 0
        target_day > days_to_ignore -> days_to_ignore
        true -> 0
      end
      |> Kernel.+(target_day)

      Utils.advance_date_by_days(end_of_month, days_to_add)
  end

  # We determine how many days to skip in the next month from the current month
  # eg to skip over April, the current month should be March
  defp days_to_skip(%{month: 1} = date) do
    date
    |> Date.leap_year?
    |> case do
      true -> 29
      false -> 28
    end
  end
  defp days_to_skip(%{month: m} = _date) when m in [3, 5, 8, 10], do: 30
  defp days_to_skip(_date), do: 0
end
