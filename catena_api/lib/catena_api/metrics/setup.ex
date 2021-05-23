defmodule CatenaApi.Metrics.Setup do
  @moduledoc false

  alias CatenaApi.Metrics.RepoInstrumenter
  alias CatenaApi.MetricsExporter

  def setup do
    MetricsExporter.setup()
    RepoInstrumenter.setup()
  end
end
