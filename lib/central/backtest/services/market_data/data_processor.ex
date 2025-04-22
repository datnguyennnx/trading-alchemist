defmodule Central.Backtest.Services.MarketData.DataProcessor do
  @moduledoc """
  Responsible for transforming, normalizing, and validating market data.
  """

  alias Central.Backtest.Schemas.MarketData
  alias Central.Backtest.Utils.BacktestUtils, as: Utils

  @doc """
  Normalizes raw binance kline data into a standard format.

  ## Parameters
    - candles: List of candle data from Binance API
    - symbol: Trading pair symbol
    - timeframe: Candle timeframe

  ## Returns
    - List of normalized candle maps
  """
  def normalize_binance_candles(candles, symbol, timeframe) do
    candles
    |> Enum.map(fn [
                     open_time,
                     open,
                     high,
                     low,
                     close,
                     volume,
                     _close_time,
                     _quote_volume,
                     _trades,
                     _taker_buy_base,
                     _taker_buy_quote,
                     _ignore
                   ] ->
      %{
        symbol: symbol,
        timeframe: timeframe,
        timestamp: Utils.DateTime.from_unix(open_time, :millisecond),
        open: Utils.Decimal.parse(open),
        high: Utils.Decimal.parse(high),
        low: Utils.Decimal.parse(low),
        close: Utils.Decimal.parse(close),
        volume: Utils.Decimal.parse(volume),
        source: "binance"
      }
    end)
    |> Enum.filter(&validate_candle/1)
  end

  @doc """
  Transforms candle structs to maps for API responses or caching.

  ## Parameters
    - candles: List of MarketData structs

  ## Returns
    - List of maps with standardized keys
  """
  def transform_candles(candles) do
    candles
    |> Enum.map(fn
      %MarketData{} = candle ->
        %{
          symbol: candle.symbol,
          timeframe: candle.timeframe,
          timestamp: candle.timestamp,
          open: candle.open,
          high: candle.high,
          low: candle.low,
          close: candle.close,
          volume: candle.volume
        }

      # Already transformed or other format
      other ->
        other
    end)
  end

  @doc """
  Calculates trading indicators for a list of candles.

  ## Parameters
    - candles: List of candle data (maps or structs)
    - indicators: List of indicators to calculate with parameters

  ## Returns
    - Candles with indicators added
  """
  def calculate_indicators(candles, indicators \\ []) do
    transformed_candles = transform_candles(candles)

    # Apply each indicator calculation
    Enum.reduce(indicators, transformed_candles, fn
      {:sma, period}, acc_candles ->
        calculate_sma(acc_candles, period)

      {:ema, period}, acc_candles ->
        calculate_ema(acc_candles, period)

      # Add more indicators as needed

      _, acc_candles ->
        # Unknown indicator, return unchanged
        acc_candles
    end)
  end

  @doc """
  Resamples candles to a larger timeframe.

  ## Parameters
    - candles: List of source candles
    - source_timeframe: Current timeframe
    - target_timeframe: Desired timeframe

  ## Returns
    - Resampled candles in the target timeframe
  """
  def resample_candles(candles, source_timeframe, target_timeframe) do
    # This is a simplified implementation
    # A complete version would handle different timeframe conversions properly

    # Convert candles to standard format
    candles = transform_candles(candles)

    # Group candles into target timeframe periods
    grouped_candles = group_candles_by_timeframe(candles, source_timeframe, target_timeframe)

    # Aggregate each group into a single candle
    Enum.map(grouped_candles, fn {timestamp, group} ->
      open = group |> Enum.at(0) |> Map.get(:open)
      close = group |> Enum.at(-1) |> Map.get(:close)
      high = group |> Enum.map(&Map.get(&1, :high)) |> Enum.max(fn -> Decimal.new(0) end)
      low = group |> Enum.map(&Map.get(&1, :low)) |> Enum.min(fn -> Decimal.new(0) end)

      volume =
        group |> Enum.map(&Map.get(&1, :volume)) |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

      %{
        symbol: group |> Enum.at(0) |> Map.get(:symbol),
        timeframe: target_timeframe,
        timestamp: timestamp,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume
      }
    end)
  end

  # PRIVATE FUNCTIONS

  defp validate_candle(candle) do
    # Check for required fields
    has_required =
      Map.has_key?(candle, :timestamp) and
        Map.has_key?(candle, :open) and
        Map.has_key?(candle, :high) and
        Map.has_key?(candle, :low) and
        Map.has_key?(candle, :close)

    # Validate values using utility functions
    valid_values =
      Utils.Decimal.compare(candle.high, candle.low) != :lt and
        Utils.Decimal.positive?(candle.open) and
        Utils.Decimal.positive?(candle.high) and
        Utils.Decimal.positive?(candle.low) and
        Utils.Decimal.positive?(candle.close)

    has_required and valid_values
  end

  # Simple Moving Average calculation
  defp calculate_sma(candles, period) do
    candles
    |> Enum.with_index()
    |> Enum.map(fn {candle, idx} ->
      if idx >= period - 1 do
        window = Enum.slice(candles, idx - period + 1, period)
        sum = window |> Enum.reduce(Decimal.new(0), fn c, acc -> Decimal.add(acc, c.close) end)
        sma = Decimal.div(sum, Decimal.new(period))

        # Add SMA to candle
        Map.put(candle, :"sma_#{period}", sma)
      else
        candle
      end
    end)
  end

  # Exponential Moving Average calculation
  defp calculate_ema(candles, period) do
    # Calculate multiplier: 2 / (period + 1)
    multiplier = Decimal.div(Decimal.new(2), Decimal.add(Decimal.new(period), Decimal.new(1)))

    # Start with SMA for initial value
    sma_candles = calculate_sma(candles, period)

    # Get the initial EMA value (which is the SMA at position period-1)
    initial_ema = Enum.at(sma_candles, period - 1) |> Map.get(:"sma_#{period}")

    # Calculate EMA for each candle after the initial period
    {ema_candles, _} =
      candles
      |> Enum.with_index()
      |> Enum.map_reduce(initial_ema, fn {candle, idx}, prev_ema ->
        if idx >= period do
          # EMA = (Close - Previous EMA) * Multiplier + Previous EMA
          ema =
            candle.close
            |> Decimal.sub(prev_ema)
            |> Decimal.mult(multiplier)
            |> Decimal.add(prev_ema)

          {Map.put(candle, :"ema_#{period}", ema), ema}
        else
          # For candles before period, just return the original candle
          {candle, prev_ema}
        end
      end)

    ema_candles
  end

  # Group candles by target timeframe
  defp group_candles_by_timeframe(candles, source_timeframe, target_timeframe) do
    # This is a simplified grouping logic and would need to be expanded for a real implementation
    # to handle all the timeframe combinations correctly

    interval_minutes = %{
      "1m" => 1,
      "5m" => 5,
      "15m" => 15,
      "30m" => 30,
      "1h" => 60,
      "2h" => 120,
      "4h" => 240,
      "6h" => 360,
      "12h" => 720,
      "1d" => 1440
    }

    source_minutes = Map.get(interval_minutes, source_timeframe, 1)
    target_minutes = Map.get(interval_minutes, target_timeframe, source_minutes)

    # Group candles by applying a floor function to their timestamps
    candles
    |> Enum.group_by(fn candle ->
      unix_time = DateTime.to_unix(candle.timestamp)
      target_seconds = target_minutes * 60
      floored_time = unix_time - rem(unix_time, target_seconds)
      DateTime.from_unix!(floored_time)
    end)
  end
end
