defmodule Catena.Core.Utils do
  @spec earlier?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean
  @spec days_to_seconds(non_neg_integer()) :: non_neg_integer
  @spec weekday(NaiveDateTime.t()) :: 1 | 2 | 3 | 4 | 5 | 6 | 7
  @spec beginning_of_week(NaiveDateTime.t()) :: NaiveDateTime.t()
  @spec same_week?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean
  @spec same_month?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean
  @spec same_year?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean
  @spec same_year?(NaiveDateTime.t(), non_neg_integer()) :: boolean
  @spec advance_date_by_months(NaiveDateTime.t(), non_neg_integer()) :: NaiveDateTime.t()
  @spec advance_date_by_days(
          NaiveDateTime.t(),
          non_neg_integer
        ) :: NaiveDateTime.t()
  @spec advance_date_by_years(NaiveDateTime.t(), non_neg_integer) :: NaiveDateTime.t()
  @spec new_id :: binary
  @spec string_id_to_binary(String.t()) :: binary
  @spec binary_id_to_string(binary) :: String.t()

  def earlier?(dt1, dt2), do: NaiveDateTime.diff(dt1, dt2) < 0

  def days_to_seconds(days), do: days * 86400

  def weekday(dt) do
    dt
    |> Date.day_of_week()
    |> Kernel.+(1)
    |> rem(7)
    |> case do
      0 -> 7
      x -> x
    end
  end

  def beginning_of_week(dt) do
    case weekday(dt) do
      1 -> dt
      x -> NaiveDateTime.add(dt, -days_to_seconds(x - 1))
    end
  end

  def same_week?(dt1, dt2), do: beginning_of_week(dt1) == beginning_of_week(dt2)

  def same_month?(%{month: m1}, %{month: m1}), do: true
  def same_month?(_dt1, _dt2), do: false

  def same_year?(%{year: y1}, %{year: y1}), do: true
  def same_year?(_dt1, _dt2), do: false

  def advance_date_by_months(date, 0), do: date

  def advance_date_by_months(%{month: m, year: y} = date, months) do
    new_month = m + months
    years_to_add = div(new_month, 12)

    new_month =
      case rem(new_month, 12) do
        0 -> 12
        x -> x
      end

    %{date | month: new_month, year: y + years_to_add}
  end

  def advance_date_by_days(date, days), do: NaiveDateTime.add(date, days_to_seconds(days))

  def advance_date_by_years(%{year: y} = date, years), do: %{date | year: years + y}

  def new_id, do: UUID.uuid4()

  def string_id_to_binary(id), do: UUID.string_to_binary!(id)

  def binary_id_to_string(binary_id), do: UUID.binary_to_string!(binary_id)
end
