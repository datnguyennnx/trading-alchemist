defmodule Central.Backtest.Services.MarketDataHandler do
  @moduledoc """
  Handles market data operations for backtesting, including data fetching,
  parsing, and formatting for strategy execution.
  """

  require Logger
  alias Central.Utils.DatetimeUtils
  alias Central.Backtest.Contexts.MarketData, as: MarketDataContext
  alias Central.Backtest.Schemas.MarketData

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

    Logger.debug("Fetching market data for backtest period: start=#{inspect(start_time)}, end=#{inspect(end_time)}, symbol=#{symbol}, timeframe=#{timeframe}")

    # Get market data from the database
    candles = MarketDataContext.get_candles(symbol, timeframe, start_time, end_time)

    # Check if we have data
    if Enum.empty?(candles) do
      Logger.error("No market data found in database for #{symbol} #{timeframe} from #{inspect(start_time)} to #{inspect(end_time)}")
      {:error, "No market data available for the specified time period"}
    else
      # Convert to maps with consistent structure
      candles_data = Enum.map(candles, fn candle ->
        %{
          timestamp: candle.timestamp,
          open: parse_decimal_or_float(candle.open),
          high: parse_decimal_or_float(candle.high),
          low: parse_decimal_or_float(candle.low),
          close: parse_decimal_or_float(candle.close),
          volume: parse_decimal_or_float(candle.volume),
          symbol: candle.symbol
        }
      end)

      # Log first candle for diagnostic purposes
      if length(candles_data) > 0 do
        first_candle = List.first(candles_data)
        Logger.debug("First candle from database: #{inspect(first_candle)}")
        Logger.info("Fetched #{length(candles_data)} candles from database for #{symbol} #{timeframe}")
      end

      {:ok, candles_data}
    end
  end

  @doc """
  Parse a value that might be a string, decimal, or number into a float.

  ## Parameters
    - value: The value to be converted to float

  ## Returns
    - float value or 0.0 if conversion fails
  """
  def parse_decimal_or_float(value) do
    cond do
      is_nil(value) ->
        0.0
      is_binary(value) ->
        case Float.parse(value) do
          {num, _} -> num
          :error -> 0.0  # Default
        end
      is_number(value) ->
        value
      # Handle Decimal type explicitly
      match?(%Decimal{}, value) ->
        Decimal.to_float(value)
      # Generic struct check as fallback
      is_struct(value) && function_exported?(value.__struct__, :to_float, 1) ->
        value.__struct__.to_float(value)
      true ->
        Logger.warn("Unknown value type for conversion: #{inspect(value)}")
        0.0  # Default
    end
  end

  @doc """
  Converts various datetime formats to UTC DateTime for database storage.
  NOTE: This is a wrapper around DatetimeUtils for backward compatibility.

  ## Parameters
    - dt: DateTime, NaiveDateTime, or ISO8601 string

  ## Returns
    - DateTime in UTC timezone or nil if conversion fails
  """
  def datetime_to_utc(dt) do
    DatetimeUtils.to_utc_datetime(dt)
  end

  @doc """
  Converts various datetime formats to NaiveDateTime.
  DEPRECATED: Use DatetimeUtils.to_utc_datetime instead for database storage.

  ## Parameters
    - dt: DateTime, NaiveDateTime, or ISO8601 string

  ## Returns
    - NaiveDateTime or nil if conversion fails
  """
  def datetime_to_naive(dt) do
    Logger.warn("datetime_to_naive is deprecated. Use DatetimeUtils.to_utc_datetime instead")
    cond do
      is_binary(dt) ->
        case NaiveDateTime.from_iso8601(dt) do
          {:ok, naive_dt} -> naive_dt
          {:error, _} ->
            Logger.warn("Failed to parse datetime string: #{inspect(dt)}")
            nil
        end
      is_map(dt) and Map.has_key?(dt, :__struct__) and dt.__struct__ == DateTime ->
        DateTime.to_naive(dt)
      is_map(dt) and Map.has_key?(dt, :__struct__) and dt.__struct__ == NaiveDateTime ->
        dt
      is_nil(dt) ->
        nil
      true ->
        Logger.warn("Unexpected datetime format: #{inspect(dt)}")
        nil
    end
  end

end
