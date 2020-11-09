defmodule EventTest do
  use ExUnit.Case, async: true
  use ScheduleBuilders
  use ScheduleAssertions

  @moduletag :event

  describe "a daily events" do
    test "for everyday" do
      event = daily_event(~N[2020-01-01 00:00:00], 1)
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [d1, d2] -> days_apart?(d2, d1, 1) end)
    end

    test "for every other day" do
      event = daily_event(~N[2020-01-01 00:00:00], 2)
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [d1, d2] -> days_apart?(d2, d1, 2) end)
    end
  end

  describe "weekly events" do
    test "for every week" do
      event = weekly_event(~N[2020-01-01 00:00:00], 1, [:su])
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [d1, d2] -> days_apart?(d2, d1, 7) end)
    end

    test "for every other week" do
      event = weekly_event(~N[2020-01-01 00:00:00], 2, [:su])
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [d1, d2] -> days_apart?(d2, d1, 14) end)
    end
  end

  describe "monthly events" do
    test "for every month" do
      event = monthly_event(~N[2020-01-01 00:00:00], 1, [1])
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [d1, d2] -> months_apart?(d1, d2, 1) end)
    end

    test "for every other month" do
      event = monthly_event(~N[2020-01-01 00:00:00], 2, [1])
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [d1, d2] -> months_apart?(d1, d2, 2) end)
    end

    test "for month-ends" do
      event = monthly_event(~N[2020-01-01 00:00:00], 1, [-1])
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert Enum.all?(dates, fn date = %{day: d} -> d == Date.days_in_month(date) end)
    end
  end

  describe "yearly events" do
    test "for every year" do
      event = yearly_event(~N[2020-01-01 00:00:00], 1, 1, [1])
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [d1, d2] -> years_apart?(d1, d2, 1) end)
    end

    test "for every other year" do
      event = yearly_event(~N[2020-01-01 00:00:00], 2, 1, [1])
      num = 4
      dates = Event.next_occurences(event, num)
      assert length(dates) == num

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [d1, d2] -> years_apart?(d1, d2, 2) end)
    end
  end

  test "one-time event" do
    event = one_time_event(~N[2020-01-01 00:00:00])
    dates = Event.next_occurences(event, 4)
    assert length(dates) == 1
    assert dates == [~N[2020-01-01 00:00:00]]
  end

  test "excluded dates are removed" do
    event = daily_event(~N[2020-01-01 00:00:00], 1)
    num = 4
    dates = Event.next_occurences(%{event | excludes: [~N[2020-01-02 00:00:00]]}, num)
    assert length(dates) == num - 1
  end

  describe "adds_start_date?" do
    test "for weekly" do
      assert Event.adds_start_date?(weekly_event(~N[2020-01-12 00:00:00], 1, [:su]))
      refute Event.adds_start_date?(weekly_event(~N[2020-01-01 00:00:00], 1, [:su]))
    end

    test "for monthly" do
      assert Event.adds_start_date?(monthly_event(~N[2020-01-01 00:00:00], 1, [1]))
      refute Event.adds_start_date?(monthly_event(~N[2020-12-31 00:00:00], 1, [1]))
    end

    test "for yearly" do
      assert Event.adds_start_date?(yearly_event(~N[2020-01-01 00:00:00], 1, 1, [1]))
      refute Event.adds_start_date?(yearly_event(~N[2020-12-31 00:00:00], 1, 1, [1]))
    end
  end
end
