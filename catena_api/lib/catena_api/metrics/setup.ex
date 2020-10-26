defmodule CatenaApi.Metrics.Setup do
  def setup do
    CatenaApi.Metrics.RepoInstrumenter.setup()
  end
end
