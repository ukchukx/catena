defmodule Catena.Core.Event do
  alias Catena.Core.Repeats.{Daily, Weekly, Monthly, Yearly}

  defstruct ~w[repeats excludes start_date]a

  @type repeat :: Daily.t() | Weekly.t() | Monthly.t() | Yearly.t()
  @type t :: %{
          repeats: nil | repeat,
          excludes: [NaiveDateTime.t()],
          start_date: NaiveDateTime.t()
        }

  @spec new(NaiveDateTime.t(), keyword) :: t()
  @spec next_occurences(t(), nil | repeat()) :: [NaiveDateTime.t()]

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

  def inflate_repetition(str) do
    [Daily, Weekly, Monthly, Yearly]
    |> Enum.map(& &1.inflate(str))
    |> Enum.find(fn
      {:error, _} -> false
      _ -> true
    end)
  end

  defp do_next_occurences(mod, event, num), do: apply(mod, :next_occurences, [event, num])
end
