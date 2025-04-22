defmodule Central.Backtest.Core.MarketData do
  @moduledoc """
  Core module for market data operations in the backtest system.
  Provides the main entry points for accessing and managing market data.
  """

  alias Central.Backtest.Contexts.MarketDataContext

  @doc """
  Gets market data for a specific symbol and timeframe within a date range.

  ## Parameters
    - symbol: The trading pair symbol (e.g., "BTCUSDT")
    - timeframe: The candle timeframe (e.g., "1m", "1h", "1d")
    - start_date: The start date/time
    - end_date: The end date/time

  ## Returns
    - List of market data candles
  """
  def get_market_data(symbol, timeframe, start_date, end_date) do
    MarketDataContext.get_candles(symbol, timeframe, start_date, end_date)
  end

  @doc """
  Triggers a synchronization of market data.

  ## Parameters
    - symbol: Optional specific symbol to sync
    - timeframe: Optional specific timeframe to sync

  ## Returns
    - :ok
  """
  def sync_market_data(symbol \\ nil, timeframe \\ nil) do
    MarketDataContext.trigger_sync(symbol, timeframe)
  end

  @doc """
  Gets the sync status of the market data.

  ## Returns
    - Map with sync status information
  """
  def get_sync_status do
    MarketDataContext.get_sync_status()
  end

  @doc """
  Gets available symbols for market data.

  ## Returns
    - List of available symbols
  """
  def get_available_symbols do
    MarketDataContext.get_available_symbols()
  end

  @doc """
  Gets available timeframes for market data.

  ## Returns
    - List of available timeframes
  """
  def get_available_timeframes do
    MarketDataContext.get_available_timeframes()
  end
end
