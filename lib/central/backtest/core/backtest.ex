defmodule Central.Backtest.Core.Backtest do
  @moduledoc """
  The Backtest context provides the core functionality for backtesting trading
  strategies against historical market data, analyzing results, and optimizing strategies.

  This context follows Elixir's context pattern for organizing business logic
  and provides a clear API for the rest of the application to interact with.
  """

  alias Central.Backtest.Services.Risk.RiskManager
  alias Central.Backtest.Services.Analysis.PerformanceCalculator
  alias Central.Backtest.Workers.BacktestRunnerWorker

  # Public API

  @doc """
  Queues a backtest for asynchronous execution.

  ## Parameters
    - backtest_id: ID of the backtest to execute
    - options: Additional options for execution (optional)

  ## Example
      iex> queue_backtest(backtest_id)
      :ok
  """
  def queue_backtest(backtest_id, options \\ %{}) do
    BacktestRunnerWorker.perform_async(Map.merge(%{"backtest_id" => backtest_id}, options))
    :ok
  end

  @doc """
  Cancels a running backtest.

  ## Parameters
    - backtest_id: ID of the backtest to cancel

  ## Example
      iex> cancel_backtest(backtest_id)
      :ok
  """
  def cancel_backtest(backtest_id) do
    BacktestRunnerWorker.cancel_backtest(backtest_id)
    :ok
  end

  @doc """
  Gets the status of the backtest runner.

  ## Returns
    - Map with runner state information

  ## Example
      iex> get_runner_status()
      %{running_count: 2, metrics: %{...}}
  """
  def get_runner_status do
    BacktestRunnerWorker.get_state()
  end

  @doc """
  Reprocesses performance metrics for a completed backtest.

  ## Parameters
    - backtest_id: ID of the backtest to analyze

  ## Returns
    - {:ok, metrics} on success
    - {:error, reason} on failure

  ## Example
      iex> reprocess_metrics(backtest_id)
      {:ok, %{win_rate: 65.0, profit_factor: 2.3, ...}}
  """
  def reprocess_metrics(backtest_id) do
    with {:ok, performance} <- PerformanceCalculator.generate_performance_summary(backtest_id),
         {:ok, risk} <- RiskManager.update_risk_metrics(backtest_id) do
      {:ok, Map.merge(performance, risk)}
    else
      error -> error
    end
  end
end
