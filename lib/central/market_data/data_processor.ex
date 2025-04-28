defmodule Central.MarketData.DataProcessor do
  @moduledoc """
  Processes raw market data into usable format for storage and potentially backtesting.
  Handles validation, normalization, and preparation for database insertion.
  """

  alias Central.Backtest.Schemas.MarketData
  alias Central.Backtest.Utils.DecimalUtils
  alias Central.Backtest.Utils.DatetimeUtils

  require Logger
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

  # Add the new validation function here as private
  # Validates candle data typically received from an exchange client (map/struct)
  # before full normalization or storage. Checks presence of keys and basic value logic.
  def validate_candle_data(candle) when is_map(candle) do
    required_keys = [:timestamp, :open, :high, :low, :close, :volume]
    has_required = Enum.all?(required_keys, &Map.has_key?(candle, &1))

    if !has_required do
       Logger.warning("Raw candle data missing required keys: #{inspect(candle)}")
      false
    else
      # Call parse/1 directly, assuming it returns Decimal or raises
      try do
        open = DecimalUtils.parse(candle.open)
        high = DecimalUtils.parse(candle.high)
        low = DecimalUtils.parse(candle.low)
        close = DecimalUtils.parse(candle.close)
        volume = DecimalUtils.parse(candle.volume)

        # Proceed with validation checks
        valid_values =
          # Ensure high >= low
          (DecimalUtils.compare(high, low) != :lt) and
          # Ensure OHLC are positive
          DecimalUtils.positive?(open) and
          DecimalUtils.positive?(high) and
          DecimalUtils.positive?(low) and
          DecimalUtils.positive?(close) and
          # Ensure Volume is non-negative
          (DecimalUtils.compare(volume, Decimal.new(0)) != :lt)

        unless valid_values do
          Logger.warning("Raw candle data has invalid values (e.g., H < L, negative price): #{inspect(candle)}")
        end
        valid_values

      rescue
         # Catch potential errors during parsing (e.g., if parse/1 raises)
        _error ->
           Logger.warning("Failed to parse decimal values in raw candle data: #{inspect(candle)}")
          false
      end
    end
  end
  def validate_candle_data(_other), do: false # Not a map

  @doc """
  Validates raw candle data from an external source and prepares it for database storage.

  Filters out invalid candles and transforms valid ones into the MarketData schema format.

  ## Parameters
    - raw_data: List of raw candle data maps/structs (e.g., from BinanceClient)
    - symbol: The trading symbol (e.g., "BTCUSDT")
    - timeframe: The timeframe (e.g., "1h")

  ## Returns
    - List of maps suitable for Repo.insert_all(MarketData, ...)
  """
  def prepare_for_storage(raw_data, symbol, timeframe) when is_list(raw_data) do
    now = DatetimeUtils.naive_utc_now_sec()

    raw_data
    |> Enum.filter(&validate_candle_data/1)
    |> Enum.map(fn candle ->
      open = DecimalUtils.parse(candle.open)
      high = DecimalUtils.parse(candle.high)
      low = DecimalUtils.parse(candle.low)
      close = DecimalUtils.parse(candle.close)
      volume = DecimalUtils.parse(candle.volume)

      timestamp = DatetimeUtils.to_utc_datetime(candle.timestamp)

      if timestamp do
        %{
          id: Ecto.UUID.generate(),
          symbol: symbol,
          timeframe: timeframe,
          timestamp: timestamp,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
          source: Map.get(candle, :source, "binance"),
          inserted_at: now
        }
      else
        Logger.warning("Skipping candle during preparation due to invalid parsed values or timestamp: #{inspect(candle)}")
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn prepared_candle -> {prepared_candle.symbol, prepared_candle.timeframe, prepared_candle.timestamp} end)
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
