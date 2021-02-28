defmodule CatenaApi.Metrics.RepoInstrumenter do
  @moduledoc false

  require Logger

  use Prometheus.Metric

  @queue_time :catena_query_queue_time
  @query_time :catena_query_query_time
  @total_time :catena_query_total_time

  @query_event [:catena, :repo, :query]

  @queue_spec [name: @queue_time, help: "Time spent waiting for connection", labels: [:query]]
  @query_spec [name: @query_time, help: "Time spent executing query", labels: [:query]]
  @total_spec [name: @total_time, help: "Total query time", labels: [:query]]

  def setup do
    Logger.info("Setting up repo instrumentation")

    Gauge.declare(@queue_spec)
    Gauge.declare(@query_spec)
    Gauge.declare(@total_spec)

    :telemetry.attach("repo", @query_event, &__MODULE__.handle_event/4, nil)
  end

  def handle_event(@query_event, measurements, %{query: q} = _metadata, _conf) do
    query = remove_unnecessary_chars(q)
    queue_time = System.convert_time_unit(measurements.queue_time, :native, :microsecond)
    query_time = System.convert_time_unit(measurements.query_time, :native, :microsecond)
    total_time = System.convert_time_unit(measurements.total_time, :native, :microsecond)

    Gauge.set([name: @queue_time, labels: [query]], queue_time)
    Gauge.set([name: @query_time, labels: [query]], query_time)
    Gauge.set([name: @total_time, labels: [query]], total_time)
  end

  defp remove_unnecessary_chars(query), do: replace_select_fields_with_star(query)

  defp replace_select_fields_with_star(query),
    do: String.replace(query, ~r/^SELECT.*FROM/, "SELECT * FROM")
end
