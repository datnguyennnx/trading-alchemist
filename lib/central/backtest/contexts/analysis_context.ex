defmodule Central.Backtest.Contexts.AnalysisContext do
  @moduledoc """
  Context for analyzing backtest results, generating reports, and providing performance insights.
  This context serves as the interface for performance analysis operations.
  """

  alias Central.Backtest.Services.Analysis.PerformanceCalculator
  alias Central.Backtest.Schemas.PerformanceSummary
  alias Central.Repo

  @doc """
  Gets a performance summary for a specific backtest.

  ## Parameters
    - backtest_id: ID of the backtest to analyze

  ## Returns
    - The performance summary or nil if not found
  """
  def get_performance_summary(backtest_id) do
    Repo.get_by(PerformanceSummary, backtest_id: backtest_id)
  end

  @doc """
  Generates a new performance summary for a backtest.

  ## Parameters
    - backtest_id: ID of the backtest to analyze

  ## Returns
    - {:ok, metrics} on success
    - {:error, reason} on failure
  """
  def generate_performance_summary(backtest_id) do
    PerformanceCalculator.generate_performance_summary(backtest_id)
  end
end
