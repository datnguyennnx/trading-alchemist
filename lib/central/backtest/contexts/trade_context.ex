defmodule Central.Backtest.Contexts.TradeContext do
  @moduledoc """
  Context module for handling trade operations.
  Delegates to TransactionContext for backward compatibility.
  """

  alias Central.Backtest.Contexts.TransactionContext

  @doc """
  Lists trades for a specific backtest.
  """
  def list_trades_for_backtest(backtest_id, opts \\ []) do
    TransactionContext.list_trades_for_backtest(backtest_id, opts)
  end

  @doc """
  Lists trades for a backtest with pagination.
  """
  def list_trades_for_backtest_paginated(backtest_id, page \\ 1, page_size \\ 50) do
    TransactionContext.list_trades_for_backtest_paginated(backtest_id, page, page_size)
  end

  @doc """
  Counts trades for a specific backtest.
  """
  def count_trades_for_backtest(backtest_id) do
    TransactionContext.count_trades_for_backtest(backtest_id)
  end

  @doc """
  Gets a trade by ID, raises if not found.
  """
  def get_trade!(id) do
    TransactionContext.get_trade!(id)
  end

  @doc """
  Gets a trade by ID and ensures it belongs to the specified backtest.
  """
  def get_trade_for_backtest!(id, backtest_id) do
    TransactionContext.get_trade_for_backtest!(id, backtest_id)
  end
end
