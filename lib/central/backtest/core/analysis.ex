defmodule Central.Backtest.Core.Analysis do
  @moduledoc """
  Core module for backtest analysis operations.
  Provides the main entry points for analyzing and reporting on backtest results.
  """

  alias Central.Backtest.Contexts.AnalysisContext

  @doc """
  Gets the performance summary for a backtest.

  ## Parameters
    - backtest_id: ID of the backtest to analyze

  ## Returns
    - The performance summary if found
    - nil if not found
  """
  def get_performance_summary(backtest_id) do
    AnalysisContext.get_performance_summary(backtest_id)
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
    AnalysisContext.generate_performance_summary(backtest_id)
  end

  @doc """
  Compares two backtests and provides a comparative analysis.

  ## Parameters
    - backtest_id_1: ID of the first backtest
    - backtest_id_2: ID of the second backtest

  ## Returns
    - Map with comparative metrics
  """
  def compare_backtests(_backtest_id_1, _backtest_id_2) do
    # This is a placeholder for future implementation
    # Will be implemented when the comparative analysis features are developed
    {:error, :not_implemented}
  end

  @doc """
  Generates a detailed report for a backtest.

  ## Parameters
    - backtest_id: ID of the backtest
    - format: Output format (e.g., :json, :csv, :pdf)

  ## Returns
    - {:ok, report} on success
    - {:error, reason} on failure
  """
  def generate_report(_backtest_id, _format \\ :json) do
    # This is a placeholder for future implementation
    # Will be implemented when reporting features are developed
    {:error, :not_implemented}
  end
end
