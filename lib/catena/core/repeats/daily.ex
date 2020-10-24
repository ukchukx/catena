defmodule Catena.Core.Repeats.Daily do
  alias Catena.Core.Repeats.Validators
  alias Catena.Core.{Event, Utils}
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
  @spec next(t(), NaiveDateTime.t()) :: NaiveDateTime.t()
  @spec next_occurences(Event.t(), non_neg_integer()) :: [NaiveDateTime.t()]

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

  defp generate_next_occurences(%Event{repeats: %__MODULE__{until: end_date} = rule} = event, num) do
    dates =
      {num, event}
      |> Stream.unfold(fn
        {1, _event} ->
          nil

        {n, event = %{start_date: prev_date}} ->
          next_date = next(rule, prev_date)

          with true <- is_nil(end_date) do
            {next_date, {n - 1, %{event | start_date: next_date}}}
          else
            false ->
              case Utils.earlier?(next_date, end_date) or next_date == end_date do
                true -> {next_date, {n - 1, %{event | start_date: next_date}}}
                false -> nil
              end
          end
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
