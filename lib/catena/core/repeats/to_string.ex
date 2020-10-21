alias Catena.Core.Repeats.{Daily, Weekly, Monthly, Yearly}

defimpl String.Chars, for: [Daily, Weekly, Monthly, Yearly] do
  alias Kernel, as: K

  def to_string(%Yearly{} = recurrence) do
    []
    |> count_or_until(recurrence)
    |> day_or_monthday(recurrence)
    |> month(recurrence)
    |> common(recurrence)
  end

  def to_string(%Monthly{} = recurrence) do
    []
    |> day_or_monthday(recurrence)
    |> common(recurrence)
  end

  def to_string(%Weekly{} = recurrence) do
    []
    |> day_or_monthday(recurrence)
    |> common(recurrence)
  end

  def to_string(%Daily{} = recurrence) do
    common([], recurrence)
  end

  defp common(parts, recurrence) do
    parts
    |> count_or_until(recurrence)
    |> interval(recurrence)
    |> frequency(recurrence)
    |> Enum.join(";")
  end

  defp count_or_until(parts, %{count: nil, until: nil}), do: parts

  defp count_or_until(parts, %{count: c}) when is_integer(c),
    do: [["COUNT=", K.to_string(c)] | parts]

  defp count_or_until(parts, %{until: u}), do: [["UNTIL=", NaiveDateTime.to_iso8601(u)] | parts]

  defp day_or_monthday(parts, %{days: nil, monthdays: nil}), do: parts

  defp day_or_monthday(parts, %{days: d}) when is_list(d),
    do: [["BYDAY=", d |> Enum.join(",") |> String.upcase()] | parts]

  defp day_or_monthday(parts, %{monthdays: d}) when is_list(d),
    do: [["BYMONTHDAY=", d |> Enum.join(",")] | parts]

  defp month(parts, %{month: nil}), do: parts

  defp month(parts, %{month: d}), do: [["BYMONTH=", K.to_string(d)] | parts]

  defp interval(parts, %{interval: i}), do: [["INTERVAL=", K.to_string(i)] | parts]

  defp frequency(parts, %Daily{}), do: [["FREQ=DAILY"] | parts]
  defp frequency(parts, %Weekly{}), do: [["FREQ=WEEKLY"] | parts]
  defp frequency(parts, %Monthly{}), do: [["FREQ=MONTHLY"] | parts]
  defp frequency(parts, %Yearly{}), do: [["FREQ=YEARLY"] | parts]
end
