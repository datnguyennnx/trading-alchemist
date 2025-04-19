defmodule Central.Backtest.Indicators.Trend.MA do
  @moduledoc """
  Moving Average calculations for various types of moving averages.

  This module provides a unified interface for calculating different types of moving averages:
  - Simple Moving Average (SMA)
  - Exponential Moving Average (EMA)
  - Weighted Moving Average (WMA)
  - Hull Moving Average (HMA)
  - Volume Weighted Moving Average (VWMA)
  """

  alias Central.Backtest.Indicators.Calculations.ListOperations
  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates a Simple Moving Average (SMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to average
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of SMA values aligned with the input candles (first period-1 values are nil)
  """
  def sma(candles, period, price_key \\ :close) when is_list(candles) and is_integer(period) and period > 0 do
    MovingAverage.sma(candles, period, price_key)
  end

  @doc """
  Calculates an Exponential Moving Average (EMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the EMA
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of EMA values aligned with the input candles (first period-1 values are nil)
  """
  def ema(candles, period, price_key \\ :close) when is_list(candles) and is_integer(period) and period > 0 do
    MovingAverage.ema(candles, period, price_key)
  end

  @doc """
  Calculates a Weighted Moving Average (WMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the WMA
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of WMA values aligned with the input candles (first period-1 values are nil)
  """
  def wma(candles, period, price_key \\ :close) when is_list(candles) and is_integer(period) and period > 0 do
    prices = ListOperations.extract_key(candles, price_key)

    # Calculate weights: 1, 2, 3, ..., period
    weights = Enum.to_list(1..period)
    weight_sum = Enum.sum(weights)

    # Calculate WMA for each window
    prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn window ->
      # Multiply each value by its weight, sum, then divide by weight sum
      weighted_sum =
        window
        |> Enum.zip(weights)
        |> Enum.map(fn {price, weight} -> Decimal.mult(price, Decimal.new(weight)) end)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

      Decimal.div(weighted_sum, Decimal.new(weight_sum))
    end)
    |> then(fn wma_values ->
      # Add nil values at the beginning to align with input
      List.duplicate(nil, period - 1) ++ wma_values
    end)
  end

  @doc """
  Calculates a Hull Moving Average (HMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the HMA
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of HMA values aligned with the input candles (first period-1 values are nil)
  """
  def hma(candles, period, price_key \\ :close) when is_list(candles) and is_integer(period) and period > 0 do
    # Hull MA = WMA(2*WMA(n/2) - WMA(n)), sqrt(n))

    # Calculate period/2 rounded down
    half_period = div(period, 2)

    # Calculate sqrt(period) rounded down
    sqrt_period = :math.sqrt(period) |> floor()

    # Step 1: Calculate WMA with period/2
    wma_half = wma(candles, half_period, price_key)

    # Step 2: Calculate WMA with full period
    wma_full = wma(candles, period, price_key)

    # Step 3: Calculate 2*WMA(n/2) - WMA(n)
    raw_data =
      Enum.zip(wma_half, wma_full)
      |> Enum.map(fn
        {nil, _} -> nil
        {_, nil} -> nil
        {half, full} ->
          Decimal.sub(
            Decimal.mult(half, Decimal.new(2)),
            full
          )
      end)

    # Create artificial candles to reuse the WMA function
    artificial_candles = Enum.map(raw_data, fn value -> %{price_key => value} end)

    # Step 4: Calculate WMA with sqrt(period) on the result
    result = wma(artificial_candles, sqrt_period, price_key)

    # Add more nil values at the beginning to properly align with original data
    additional_padding = period - half_period + sqrt_period - 1
    List.duplicate(nil, additional_padding) ++ Enum.drop(result, period)
  end

  @doc """
  Calculates a Volume Weighted Moving Average (VWMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the VWMA
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of VWMA values aligned with the input candles (first period-1 values are nil)
  """
  def vwma(candles, period, price_key \\ :close) when is_list(candles) and is_integer(period) and period > 0 do
    # Need at least period candles with volume
    if length(candles) < period do
      List.duplicate(nil, length(candles))
    else
      # Calculate VWMA for each window
      candles
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn window ->
        volume_sum = Enum.reduce(window, Decimal.new(0), fn candle, acc ->
          Decimal.add(acc, Map.get(candle, :volume))
        end)

        if Decimal.equal?(volume_sum, Decimal.new(0)) do
          # If no volume, return nil (or could use a regular SMA instead)
          nil
        else
          # Calculate sum of price * volume
          price_volume_sum = Enum.reduce(window, Decimal.new(0), fn candle, acc ->
            price = Map.get(candle, price_key)
            volume = Map.get(candle, :volume)
            Decimal.add(acc, Decimal.mult(price, volume))
          end)

          # VWMA = sum(price * volume) / sum(volume)
          Decimal.div(price_volume_sum, volume_sum)
        end
      end)
      |> then(fn vwma_values ->
        # Add nil values at the beginning to align with input
        List.duplicate(nil, period - 1) ++ vwma_values
      end)
    end
  end
end
