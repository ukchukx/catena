defmodule Catena.Core.Repeats.Yearly do
  alias Catena.Core.Repeats.Validators
  alias Catena.Core.{Event, Utils}

  # FREQ=YEARLY;INTERVAL=1;BYMONTH=1;BYDAY=1SU,1TU;COUNT=5 - year by day
  # FREQ=YEARLY;INTERVAL=1;BYMONTH=1;BYMONTHDAY=1,2;COUNT=5 - year by date

  # TODO
  # Implement for byday

  @enforce_keys ~w[interval]a
  defstruct ~w[interval days monthdays month count until]a

  @type monthday :: 1..31
  @type month :: 1..12
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
          monthdays: nil | [monthday, ...],
          month: month,
          count: nil | integer,
          until: nil | NaiveDateTime.t()
        }

  @spec inflate(binary) :: {:error, any} | t
  @spec new(non_neg_integer(), month, keyword) :: {:error, any} | t
  @spec next(t(), NaiveDateTime.t()) :: [NaiveDateTime.t()]
  @spec next_occurences(Event.t(), non_neg_integer()) :: [NaiveDateTime.t()]

  def inflate("FREQ=YEARLY;" <> str) do
    params = Utils.repetition_string_to_keyword(str)
    new(params[:interval], params[:month], params)
  end

  def inflate(_str), do: {:error, "not a yearly rule"}

  def new(interval, month, opts \\ []) do
    opts
    |> Keyword.has_key?(:monthdays)
    |> case do
      false -> %{days: Keyword.get(opts, :days)}
      true -> %{monthdays: Keyword.get(opts, :monthdays)}
    end
    |> Map.put(:interval, interval)
    |> Map.put(:month, month)
    |> get_optional_params_validate_and_create(opts)
  end

  def next(%__MODULE__{interval: n, month: m, monthdays: [day]}, from_date)
      when is_integer(day) do
    [advance_date_to_next_year(from_date, m, day, n)]
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
    next_date = advance_date_to_next_year(start_date, rule.month, Enum.at(days, current_index), n)

    do_next(rule, start_date, [next_date | acc], next_current_index)
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
    extra_validators = [&Validators.validate_month/1, &Validators.validate_day_or_monthday/1]

    attrs
    |> Validators.validate(extra_validators)
    |> case do
      :ok -> struct!(__MODULE__, attrs)
      err -> err
    end
  end

  defp advance_date_to_next_year(%{day: day} = date, target_month, target_day, interval) do
    days_to_add =
      case day < target_day do
        true -> target_day - day
        false -> Date.days_in_month(date) - day + target_day
      end

    %{month: current_month} = new_date = Utils.advance_date_by_days(date, days_to_add)

    # then advance days
    # then check interval and advance
    months_to_add =
      cond do
        current_month == target_month -> 12
        target_month < current_month -> 12 - current_month + target_month
        target_month > current_month -> target_month - current_month
      end

    new_date = Utils.advance_date_by_months(new_date, months_to_add)

    years_to_add =
      case Utils.same_year?(date, new_date) do
        true -> interval
        false -> interval - 1
      end

    Utils.advance_date_by_years(new_date, years_to_add)
  end
end
