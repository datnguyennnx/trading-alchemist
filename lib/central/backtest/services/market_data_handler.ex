defmodule Central.Backtest.Services.MarketDataHandler do
  @moduledoc """
  Handles market data operations for backtesting, including data fetching,
  parsing, and formatting for strategy execution.
  """

  require Logger
  # Remove unused alias
  # alias Central.Utils.DatetimeUtils
  alias Central.Backtest.Contexts.MarketData, as: MarketDataContext
  alias Central.Backtest.Services.HistoricalDataFetcher
  alias Central.Backtest.Contexts.BacktestContext
  alias Central.Backtest.Utils.BacktestUtils, as: Utils

  @doc """
  Fetches market data for a backtest period.

  ## Parameters
    - backtest: The backtest struct containing configuration parameters

  ## Returns
    - {:ok, data} where data is a list of candle maps with OHLCV data
    - {:error, reason} on failure
  """
  def fetch_market_data(backtest) do
    # Use real market data from the database
    start_time = backtest.start_time || DateTime.add(DateTime.utc_now(), -30, :day)
    end_time = backtest.end_time || DateTime.utc_now()
    symbol = backtest.symbol || "BTCUSDT"
    timeframe = backtest.timeframe || "1h"

    Logger.debug(
      "Fetching market data for backtest period: start=#{inspect(start_time)}, end=#{inspect(end_time)}, symbol=#{symbol}, timeframe=#{timeframe}"
    )

    # First, check if we have all the required data
    case check_data_availability(symbol, timeframe, start_time, end_time) do
      :ok ->
        # All data is available, proceed with fetching
        fetch_and_format_candles(symbol, timeframe, start_time, end_time)

      {:missing, missing_ranges} ->
        # Update backtest status to indicate we're fetching data
        if backtest.id do
          BacktestContext.update_backtest(backtest, %{status: :fetching_data})
        end

        # Log the missing ranges
        Logger.info("Missing data detected for #{symbol}/#{timeframe}. Fetching required historical data...")

        # Fetch each missing range
        fetch_results =
          Enum.map(missing_ranges, fn {range_start, range_end} ->
            Logger.info("Fetching range #{DateTime.to_iso8601(range_start)} to #{DateTime.to_iso8601(range_end)}")
            HistoricalDataFetcher.fetch_and_store_range(symbol, timeframe, range_start, range_end)
          end)

        # Check if all fetches were successful
        errors = Enum.filter(fetch_results, fn {status, _} -> status == :error end)

        if errors != [] do
          # At least one fetch failed
          {_, reason} = List.first(errors)

          # Update backtest status if available
          if backtest.id do
            BacktestContext.update_backtest(backtest, %{
              status: :failed,
              error_message: "Failed to fetch required historical data: #{reason}"
            })
          end

          {:error, "Failed to fetch required historical data: #{reason}"}
        else
          # All fetches succeeded, now we can get the data
          Logger.info("Successfully fetched all required historical data. Proceeding with backtest.")

          # If backtest has an ID, update its status back to pending
          if backtest.id do
            BacktestContext.update_backtest(backtest, %{status: :pending})
          end

          # Now fetch the data normally
          fetch_and_format_candles(symbol, timeframe, start_time, end_time)
        end
    end
  end

  # Checks if all required market data is available for the given parameters.
  #
  # Returns:
  #   - :ok if all data is available
  #   - {:missing, ranges} where ranges is a list of {start_time, end_time} tuples representing missing data
  defp check_data_availability(symbol, timeframe, start_time, end_time) do
    # Get the current data range for this symbol/timeframe
    {db_start, db_end} = MarketDataContext.get_date_range(symbol, timeframe)

    # Initialize empty list for missing ranges
    missing_ranges_list = []

    # Case 1: No data exists at all
    missing_ranges_list =
      if is_nil(db_start) or is_nil(db_end) do
        # The entire range is missing
        [{start_time, end_time}]
      else
        # Default to empty list if data exists
        missing_ranges_list
      end

    # Case 2: Check if requested start_time is earlier than available data
    missing_ranges_list =
      if not is_nil(db_start) and Utils.DateTime.diff(start_time, db_start) < 0 do
        # Add the missing early range
        [{start_time, Utils.DateTime.add(db_start, -1, :second)} | missing_ranges_list]
      else
        missing_ranges_list
      end

    # Case 3: Check if requested end_time is later than available data
    missing_ranges_list =
      if not is_nil(db_end) and Utils.DateTime.diff(end_time, db_end) > 0 do
        # Add the missing later range
        missing_ranges_list ++ [{Utils.DateTime.add(db_end, 1, :second), end_time}]
      else
        missing_ranges_list
      end

    # Case 4: Check for gaps in the middle (this could be more complex in a real implementation)
    # For simplicity, we're not implementing gap detection in this example

    # Return the result
    if missing_ranges_list == [] do
      :ok
    else
      {:missing, missing_ranges_list}
    end
  end

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

    # Check if we have data
    if Enum.empty?(candles) do
      Logger.error(
        "No market data found in database for #{symbol} #{timeframe} from #{inspect(start_time)} to #{inspect(end_time)}"
      )

      {:error, "No market data available for the specified time period"}
    else
      # Convert to maps with consistent structure
      candles_data =
        Enum.map(candles, fn candle ->
          %{
            timestamp: candle.timestamp,
            open: Utils.Decimal.to_float(candle.open),
            high: Utils.Decimal.to_float(candle.high),
            low: Utils.Decimal.to_float(candle.low),
            close: Utils.Decimal.to_float(candle.close),
            volume: Utils.Decimal.to_float(candle.volume),
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

  @doc """
  Parse a value that might be a string, decimal, or number into a float.
  DEPRECATED: Use BacktestUtils.Decimal.to_float instead.

  ## Parameters
    - value: The value to be converted to float

  ## Returns
    - float value or 0.0 if conversion fails
  """
  def parse_decimal_or_float(value) do
    Logger.warning("parse_decimal_or_float is deprecated. Use BacktestUtils.Decimal.to_float instead")
    Utils.Decimal.to_float(value)
  end

  @doc """
  Converts various datetime formats to UTC DateTime for database storage.
  DEPRECATED: Use BacktestUtils.DateTime.to_utc instead.

  ## Parameters
    - dt: DateTime, NaiveDateTime, or ISO8601 string

  ## Returns
    - DateTime in UTC timezone or nil if conversion fails
  """
  def datetime_to_utc(dt) do
    Logger.warning("datetime_to_utc is deprecated. Use BacktestUtils.DateTime.to_utc instead")
    Utils.DateTime.to_utc(dt)
  end

  @doc """
  Converts various datetime formats to NaiveDateTime.
  DEPRECATED: Use BacktestUtils.DateTime.to_utc instead for database storage.

  ## Parameters
    - dt: DateTime, NaiveDateTime, or ISO8601 string

  ## Returns
    - NaiveDateTime or nil if conversion fails
  """
  def datetime_to_naive(dt) do
    Logger.warning("datetime_to_naive is deprecated. Use BacktestUtils.DateTime.to_utc instead")

    # Maintain backwards compatibility
    case Utils.DateTime.to_utc(dt) do
      %DateTime{} = datetime -> DateTime.to_naive(datetime)
      nil -> nil
    end
  end
end
