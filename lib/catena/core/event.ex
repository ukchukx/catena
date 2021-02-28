defmodule Catena.Core.Event do
  @moduledoc false

  alias Catena.Core.Repeats.{Daily, Monthly, Weekly, Yearly}

  defstruct ~w[repeats excludes start_date]a

  @type repeat :: Daily.t() | Weekly.t() | Monthly.t() | Yearly.t()
  @type t :: %{
          repeats: nil | repeat,
          excludes: [NaiveDateTime.t()],
          start_date: NaiveDateTime.t()
        }

  @spec inflate_repetition(binary) :: repeat | nil

  def new(start_date, opts \\ []) do
    attrs = %{
      repeats: Keyword.get(opts, :repeats),
      excludes: Keyword.get(opts, :excludes, []),
      start_date: start_date
    }

    struct!(__MODULE__, attrs)
  end

  def next_occurences(%__MODULE__{repeats: nil, start_date: start_date}, _num),
    do: [start_date]

  def next_occurences(%__MODULE__{repeats: %Daily{}} = event, num),
    do: do_next_occurences(Daily, event, num)

  def next_occurences(%__MODULE__{repeats: %Weekly{}} = event, num),
    do: do_next_occurences(Weekly, event, num)

  def next_occurences(%__MODULE__{repeats: %Monthly{}} = event, num),
    do: do_next_occurences(Monthly, event, num)

  def next_occurences(%__MODULE__{repeats: %Yearly{}} = event, num),
    do: do_next_occurences(Yearly, event, num)

  def inflate_repetition(str) when is_binary(str) do
    [Daily, Weekly, Monthly, Yearly]
    |> Enum.map(& &1.inflate(String.upcase(str)))
    |> Enum.find(fn
      {:error, _} -> false
      _ -> true
    end)
  end

  def adds_start_date?(%__MODULE__{repeats: nil}), do: nil

  def adds_start_date?(%__MODULE__{repeats: %Daily{}}), do: true

  def adds_start_date?(%__MODULE__{repeats: %Weekly{}} = event),
    do: do_adds_start_date?(Weekly, event)

  def adds_start_date?(%__MODULE__{repeats: %Monthly{}} = event),
    do: do_adds_start_date?(Monthly, event)

  def adds_start_date?(%__MODULE__{repeats: %Yearly{}} = event),
    do: do_adds_start_date?(Yearly, event)

  defp do_adds_start_date?(mod, event), do: apply(mod, :adds_start_date?, [event])

  defp do_next_occurences(mod, %{excludes: excludes} = event, num) do
    mod
    |> apply(:next_occurences, [event, num])
    |> Enum.filter(&(&1 not in excludes))
  end
end
