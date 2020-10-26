defmodule CatenaApi.Metrics.Setup do
  def setup do
    CatenaApi.MetricsExporter.setup()
    CatenaApi.Metrics.RepoInstrumenter.setup()
  end
end
