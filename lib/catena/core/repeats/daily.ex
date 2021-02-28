defmodule Catena.Core.Repeats.Daily do
  @moduledoc false

  alias Catena.Core.{Event, Utils}
  alias Catena.Core.Repeats.Utils, as: RepeatUtils
  alias Catena.Core.Repeats.Validators
  # FREQ=DAILY;INTERVAL=1;COUNT=5 - every day
  # FREQ=DAILY;INTERVAL=2 - every other day

  @enforce_keys ~w[interval]a
  defstruct ~w[interval count until]a

  @type t :: %{
          interval: integer,
          count: nil | integer,
          until: nil | NaiveDateTime.t()
        }

  @spec inflate(binary) :: {:error, any} | t
  @spec new(non_neg_integer(), keyword) :: {:error, any} | t

  def inflate("FREQ=DAILY;" <> str) do
    params = Utils.repetition_string_to_keyword(str)
    new(params[:interval], params)
  end

  def inflate(_str), do: {:error, "not a daily rule"}

  def new(interval, opts \\ []) do
    get_optional_params_validate_and_create(%{interval: interval}, opts)
  end

  def next(%__MODULE__{interval: n}, from_date),
    do: NaiveDateTime.add(from_date, Utils.days_to_seconds(n))

  def next_occurences(%Event{repeats: %__MODULE__{count: nil}} = event, num) do
    generate_next_occurences(event, num)
  end

  def next_occurences(%Event{repeats: %__MODULE__{count: num}} = event, _num) do
    generate_next_occurences(event, num)
  end

  defp generate_next_occurences(%Event{repeats: %__MODULE__{} = rule} = event, num) do
    dates =
      {num, event}
      |> Stream.unfold(fn
        {1, _event} ->
          nil

        {n, event = %{start_date: prev_date}} ->
          rule
          |> next(prev_date)
          |> RepeatUtils.accumulate_daily_result(event, n - 1)
      end)
      |> Enum.to_list()

    [event.start_date | dates]
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
    |> Validators.validate()
    |> case do
      :ok -> struct!(__MODULE__, attrs)
      err -> err
    end
  end
end
