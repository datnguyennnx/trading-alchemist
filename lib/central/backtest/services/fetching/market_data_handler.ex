defmodule Central.Backtest.Services.Fetching.MarketDataHandler do
  @moduledoc """
  Handles fetching and coordinating market data operations.
  """

  require Logger
  alias Central.Backtest.Contexts.MarketDataContext
  # Remove alias to HistoricalDataFetcher, as it's now handled by SyncService
  # alias Central.Backtest.Services.MarketData.HistoricalDataFetcher
  # Use the new service
  alias Central.MarketData.SyncService
  alias Central.Backtest.Contexts.BacktestContext
  alias Central.Backtest.Utils.DecimalUtils

  @doc """
  Ensures data is available and fetches market data for a backtest period.

  First, it calls `SyncService.ensure_data_range` to check and fetch missing data.
  If successful, it retrieves the candles for the specified range using `MarketDataContext`.

  ## Parameters
    - backtest: The backtest struct containing configuration parameters

  ## Returns
    - {:ok, data} where data is a list of candle maps with OHLCV data
    - {:error, reason} on failure during data availability check or fetching
  """
  def fetch_market_data(backtest) do
    start_time = backtest.start_time || DateTime.add(DateTime.utc_now(), -30, :day)
    end_time = backtest.end_time || DateTime.utc_now()
    symbol = backtest.symbol || "BTCUSDT"
    timeframe = backtest.timeframe || "1h"

    Logger.debug(
      "Requesting market data for backtest period: start=#{inspect(start_time)}, end=#{inspect(end_time)}, symbol=#{symbol}, timeframe=#{timeframe}"
    )

    # Step 1: Ensure data range is available using the SyncService
    case SyncService.ensure_data_range(symbol, timeframe, start_time, end_time) do
      {:ok, :available} ->
        Logger.info("Data confirmed available for #{symbol}/#{timeframe}. Fetching from DB...")
        fetch_and_format_candles(symbol, timeframe, start_time, end_time)

      {:ok, :synced} ->
        # If backtest has an ID, update status to pending as fetching is now complete.
        # This assumes the status might have been 'fetching_data' if triggered elsewhere,
        # or simply ensures it's ready after potentially blocking fetches.
        if backtest.id do
          Logger.info("SyncService fetched missing data. Updating backtest status to pending.")
          BacktestContext.update_backtest(backtest, %{status: :pending})
        end

        Logger.info(
          "SyncService fetched missing data for #{symbol}/#{timeframe}. Fetching from DB..."
        )

        fetch_and_format_candles(symbol, timeframe, start_time, end_time)

      {:error, reason} ->
        Logger.error("Failed to ensure data availability for backtest: #{reason}")
        error_message = "Failed to prepare required historical data: #{reason}"
        # Update backtest status if available
        if backtest.id do
          BacktestContext.update_backtest(backtest, %{
            status: :failed,
            error_message: error_message
          })
        end

        {:error, error_message}
    end
  end

  # Remove check_data_availability function as it's moved to SyncService
  # defp check_data_availability(symbol, timeframe, start_time, end_time) do
  #   ...
  # end

  # Fetches and formats candles from the database.
  #
  # Parameters:
  #   - symbol: Trading pair
  #   - timeframe: Timeframe
  #   - start_time: Start time of the range
  #   - end_time: End time of the range
  #
  # Returns:
  #   - {:ok, candles_data} on success
  #   - {:error, reason} on failure
  defp fetch_and_format_candles(symbol, timeframe, start_time, end_time) do
    # Get market data from the database
    candles = MarketDataContext.get_candles(symbol, timeframe, start_time, end_time)

    # Check if we have data (after SyncService confirmed availability)
    if Enum.empty?(candles) do
      # This case might indicate an issue if SyncService reported OK
      # but could happen if the requested range is valid but empty (e.g., market closed)
      Logger.warning(
        "No market data found in database for #{symbol} #{timeframe} from #{inspect(start_time)} to #{inspect(end_time)} despite SyncService success."
      )

      # Decide if this should be an error for the backtest or an empty dataset
      # Returning empty list might be acceptable for backtesting
      {:ok, []}

      # Or: {:error, "No market data available for the specified time period, even after sync check."}
    else
      # Convert to maps with consistent structure
      candles_data =
        Enum.map(candles, fn candle ->
          %{
            timestamp: candle.timestamp,
            # Use DecimalUtils
            open: DecimalUtils.to_float(candle.open),
            high: DecimalUtils.to_float(candle.high),
            low: DecimalUtils.to_float(candle.low),
            close: DecimalUtils.to_float(candle.close),
            volume: DecimalUtils.to_float(candle.volume),
            symbol: candle.symbol
          }
        end)

      # Log first candle for diagnostic purposes
      if length(candles_data) > 0 do
        first_candle = List.first(candles_data)
        Logger.debug("First candle from database: #{inspect(first_candle)}")

        Logger.info(
          "Fetched #{length(candles_data)} candles from database for #{symbol} #{timeframe}"
        )
      end

      {:ok, candles_data}
    end
  end
end
