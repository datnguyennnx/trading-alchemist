defmodule Central.MarketData.ChartDataFetcher do
  @moduledoc """
  Provides functions to fetch historical market data specifically for chart rendering.

  It prioritizes fetching from the database if available, then falls back to
  fetching directly from the exchange (e.g., Binance) without necessarily
  storing the data permanently. Includes considerations for caching.
  """

  require Logger

  alias Central.Backtest.Contexts.MarketDataContext
  alias Central.MarketData.Exchange.Binance.Client, as: BinanceClient
  alias Central.Helpers.TimeframeHelper
  # Consider adding a cache like Cachex or ConCache
  # alias Central.Cache # Example

  # TODO: Implement caching strategy (e.g., ETS, Cachex)
  # @cache_name :chart_data_cache

  @doc """
  Fetches historical chart data for a given symbol, timeframe, and range.

  Attempts to load from DB first, then fetches from Binance if needed.
  Data fetched directly from Binance is *not* stored in the DB by this function.

  ## Parameters
    - symbol: Trading pair symbol (e.g., "BTCUSDT")
    - timeframe: Candle timeframe (e.g., "1h")
    - start_time: The required start DateTime (UTC)
    - end_time: The required end DateTime (UTC)

  ## Returns
    - `{:ok, candles_data}`: List of candle maps suitable for charting.
    - `{:error, reason}`: If fetching failed.
  """
  def get_chart_data(symbol, timeframe, start_time, end_time) do
    Logger.debug("Fetching chart data for #{symbol}/#{timeframe} from #{start_time} to #{end_time}")

    # 1. TODO: Check cache first
    # case Cache.get(@cache_name, {symbol, timeframe, start_time, end_time}) do
    #   {:ok, cached_data} ->
    #     Logger.debug("Cache hit for chart data #{symbol}/#{timeframe}")
    #     {:ok, cached_data}
    #   :error ->
    #     fetch_from_db_or_exchange(symbol, timeframe, start_time, end_time)
    # end

    # For now, directly fetch
    fetch_from_db_or_exchange(symbol, timeframe, start_time, end_time)

  end


   @doc """
  Fetches a chunk of historical data ending *before* a given timestamp, for infinite scroll.

  Attempts to load from DB first, then fetches from Binance if needed.
  Data fetched directly from Binance is *not* stored in the DB by this function.

  ## Parameters
    - symbol: Trading pair symbol (e.g., "BTCUSDT")
    - timeframe: Candle timeframe (e.g., "1h")
    - before_timestamp: Fetch data ending before this DateTime (UTC)
    - limit: Maximum number of candles to fetch

  ## Returns
    - `{:ok, candles_data}`: List of candle maps suitable for charting.
    - `{:error, reason}`: If fetching failed.
  """
  def get_historical_chunk(symbol, timeframe, before_timestamp, limit \\ 100) do
     Logger.debug("Fetching historical chunk for #{symbol}/#{timeframe} before #{before_timestamp}, limit #{limit}")
    # This requires careful calculation of start/end times based on 'before_timestamp' and 'limit'

    # Fetch data strictly *before* the specified timestamp
    end_time = DateTime.add(before_timestamp, -1, :second)

    # Calculate the duration of the timeframe in seconds
    timeframe_seconds = TimeframeHelper.timeframe_to_seconds(timeframe)

    if timeframe_seconds == 0 do
       Logger.error("Invalid timeframe '#{timeframe}' provided to get_historical_chunk.")
      {:error, :invalid_timeframe}
    else
      # Calculate the approximate start time to fetch 'limit' candles ending at 'end_time'.
      # Fetch slightly more to ensure we have enough data if there are gaps.
      # Calculate the total seconds needed for the requested limit + a small buffer (e.g., 10 candles).
      buffer_candles = 10
      total_seconds_needed = timeframe_seconds * (limit + buffer_candles)

      # Subtract the total seconds needed from the end_time to get the start_time.
      start_time = DateTime.add(end_time, -total_seconds_needed, :second)

       # Fetch the calculated range using the existing helper
       # The helper handles DB check first, then exchange fallback.
      case fetch_from_db_or_exchange(symbol, timeframe, start_time, end_time) do
         {:ok, candles} ->
           # Sort descending by timestamp and take the requested limit
           # to get the candles immediately preceding the 'before_timestamp'.
           sorted_candles = Enum.sort_by(candles, & &1.timestamp, {:desc, DateTime})
           chunk = Enum.take(sorted_candles, limit)
           # Return the chunk sorted ascending for the chart
           {:ok, Enum.reverse(chunk)}
         {:error, reason} ->
            # Log the specific error from the fetcher
           Logger.error("Failed to fetch historical chunk for #{symbol}/#{timeframe}: #{inspect(reason)}")
           {:error, reason} # Propagate the error
      end
    end
     # Logger.warning("get_historical_chunk logic is not fully implemented yet.")
     # {:ok, []} # Removed stub implementation
  end


  # --- Private Helpers ---

  defp fetch_from_db_or_exchange(symbol, timeframe, start_time, end_time) do
    case MarketDataContext.get_candles(symbol, timeframe, start_time, end_time) do
      [] ->
        Logger.info("No data found in DB for #{symbol}/#{timeframe} in range. Fetching from exchange...")
        fetch_directly_from_binance(symbol, timeframe, start_time, end_time)

      db_candles ->
        Logger.debug("Found #{length(db_candles)} candles in DB for #{symbol}/#{timeframe}")
        # Ensure data covers the *full* requested range (simplistic check)
        # A more robust check would compare first/last candle timestamps precisely
        # For now, assume if we get *any* data, it's good enough for this simple version
        if length(db_candles) > 0 do
           {:ok, format_db_candles(db_candles)}
        else
           # This case implies get_candles returned non-[] but it was empty after checks? Unlikely.
           Logger.info("DB returned data, but it seems empty for #{symbol}/#{timeframe}. Fetching from exchange.")
           fetch_directly_from_binance(symbol, timeframe, start_time, end_time)
        end
        # TODO: Add logic to check if db_candles fully cover the required range [start_time, end_time]
        # If not, fetch the missing parts from Binance and merge.
        # For now, return DB data if any found.
        # {:ok, format_db_candles(db_candles)}
    end
  end


  defp fetch_directly_from_binance(symbol, timeframe, start_time, end_time) do
     # Note: Binance API has a limit (e.g., 1000 candles). Need chunking for large ranges.
     # HistoricalDataFetcher already implements chunking. We might reuse that logic
     # or implement a simpler version here if chart requests are typically smaller.
     # For now, assume the range is small enough for one request or use a default limit.
    limit = 1000 # Use Binance max limit
    case BinanceClient.get_klines(symbol, timeframe, start_time: start_time, end_time: end_time, limit: limit) do
      {:ok, raw_candles} ->
        Logger.debug("Fetched #{length(raw_candles)} raw candles from Binance for #{symbol}/#{timeframe}")
        processed_candles = format_exchange_candles(raw_candles)

        # TODO: Add data to cache
        # Cache.put(@cache_name, {symbol, timeframe, start_time, end_time}, processed_candles)

        {:ok, processed_candles}

      {:error, reason} ->
         Logger.error("Failed to fetch chart data from Binance for #{symbol}/#{timeframe}: #{inspect(reason)}")
        {:error, "Failed to fetch data from exchange: #{reason}"}
    end
  end

  # Format candles fetched from the database
  defp format_db_candles(db_candles) do
    Enum.map(db_candles, fn candle ->
      # Convert Decimals to floats for charting libraries
      %{
        timestamp: candle.timestamp,
        open: Decimal.to_float(candle.open),
        high: Decimal.to_float(candle.high),
        low: Decimal.to_float(candle.low),
        close: Decimal.to_float(candle.close),
        volume: Decimal.to_float(candle.volume)
      }
    end)
  end

  # Format candles received directly from the exchange client (BinanceClient)
  # Assumes BinanceClient returns maps with string values for OHLCV
  defp format_exchange_candles(raw_candles) do
    Enum.map(raw_candles, fn candle ->
      # Basic validation and conversion
      try do
         %{
           timestamp: candle.timestamp, # Assumes BinanceClient already converts to DateTime
           open: String.to_float(candle.open),
           high: String.to_float(candle.high),
           low: String.to_float(candle.low),
           close: String.to_float(candle.close),
           volume: String.to_float(candle.volume)
         }
      rescue
         # Log and skip invalid data points
        _ ->
           Logger.warning("Skipping invalid raw candle data from exchange: #{inspect(candle)}")
           nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    # Ensure candles are sorted by timestamp ascending
    |> Enum.sort_by(& &1.timestamp)
  end

end
