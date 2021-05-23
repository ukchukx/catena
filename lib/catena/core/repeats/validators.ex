defmodule Catena.Core.Repeats.Validators do
  @moduledoc false

  def validate(%{} = attrs, extra_validators \\ []) do
    extra_validators
    |> Kernel.++([&validate_interval/1, &validate_count_or_until/1])
    |> Enum.reduce([], fn validator, errors ->
      case apply(validator, [attrs]) do
        :ok -> errors
        {:error, err} -> [err | errors]
      end
    end)
    |> case do
      [] -> :ok
      err_list -> {:error, err_list}
    end
  end

  def validate_interval(%{interval: i}) when is_integer(i) and i > 0, do: :ok

  def validate_interval(_), do: {:error, "interval is invalid"}

  def validate_count_or_until(%{count: c}) when not is_nil(c) do
    case is_integer(c) and c > 0 do
      true -> :ok
      false -> {:error, "count is not an integer"}
    end
  end

  def validate_count_or_until(%{until: u}) when not is_nil(u) do
    case is_struct(u) and u.__struct__ == NaiveDateTime do
      true -> :ok
      false -> {:error, "until is not a NaiveDateTime"}
    end
  end

  def validate_count_or_until(_), do: :ok

  def validate_day_or_monthday(%{days: d}) when not is_nil(d) do
    validate_ordday(d)
  end

  def validate_day_or_monthday(%{monthdays: m}) when not is_nil(m) do
    validate_monthday(m)
  end

  def validate_day_or_monthday(_),
    do: {:error, "either days or monthdays is required"}

  def validate_day(%{days: d}) do
    d
    |> Enum.all?(&valid_day?/1)
    |> case do
      true -> :ok
      false -> {:error, "invalid days value. Should be a list of weekdays"}
    end
  end

  def validate_ordday(d) do
    d
    |> Enum.all?(&valid_ordday?/1)
    |> case do
      true -> :ok
      false -> {:error, "invalid day value. Should be a list of orddays"}
    end
  end

  def validate_monthday(m) when is_list(m) do
    m
    |> Enum.all?(&((&1 >= 1 and &1 <= 31) or &1 == -1))
    |> case do
      true -> :ok
      false -> {:error, "monthdays value is not a valid day of the month"}
    end
  end

  def validate_monthday(_), do: {:error, "monthdays should be a monthday list"}

  def validate_month(%{month: m}) when is_integer(m) and m >= 1 and m <= 12, do: :ok
  def validate_month(_), do: {:error, "month value is not a valid month of the year"}

  days = ~w[su mo tu we th fr sa]
  nums = ~w[1 2 3 4 -1]

  for d <- days do
    def valid_day?(unquote(String.to_atom(d))), do: true
  end

  def valid_day?(_), do: false

  for d <- days do
    Enum.map(nums, fn n -> n <> d end)
  end
  |> List.flatten()
  |> Enum.map(&String.to_atom/1)
  |> Enum.each(fn ordday ->
    def valid_ordday?(unquote(ordday)), do: true
  end)

  def valid_ordday?(_), do: false
end
