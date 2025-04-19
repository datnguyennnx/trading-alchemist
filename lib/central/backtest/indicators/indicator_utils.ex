defmodule Central.Backtest.Indicators.IndicatorUtils do
  @moduledoc """
  Utility functions for technical indicators.

  This module provides common helper functions used across different indicators
  to avoid code duplication and maintain consistency.
  """

  alias Central.Backtest.Indicators.Calculations.ListOperations

  @doc """
  Extracts price data from a list of candles.

  ## Parameters
    - candles: List of OHLCV candle data
    - price_type: The price type to extract (:open, :high, :low, :close, :volume)

  ## Returns
    - List of price values
  """
  @spec extract_price(list(), atom()) :: list()
  def extract_price(candles, price_type) do
    ListOperations.extract_key(candles, price_type)
  end

  @doc """
  Adds nil values to the beginning of a list.

  ## Parameters
    - list: The list to pad
    - count: Number of nil values to add to the beginning

  ## Returns
    - Padded list
  """
  @spec pad_beginning(list(), non_neg_integer()) :: list()
  def pad_beginning(list, count) do
    List.duplicate(nil, count) ++ list
  end

  @doc """
  Normalizes output data by padding beginning values and handling nil values.

  ## Parameters
    - list: List of indicator values

  ## Returns
    - Normalized list
  """
  @spec normalize_output(list()) :: list()
  def normalize_output(list) do
    # Simple implementation - we could add more complex normalization here
    list
  end

  @doc """
  Combines indicator values with candle data to include timestamps.

  ## Parameters
    - candles: Original candle data
    - values: Calculated indicator values
    - value_key: Key to use for the indicator values in result maps

  ## Returns
    - List of maps with timestamp and indicator value
  """
  @spec with_timestamp(list(), list(), atom()) :: list()
  def with_timestamp(candles, values, value_key) do
    Enum.zip(candles, values)
    |> Enum.map(fn {candle, value} ->
      Map.put(%{timestamp: Map.get(candle, :timestamp)}, value_key, value)
    end)
  end

  @doc """
  Calculates a Simple Moving Average (SMA).

  ## Parameters
    - data: List of price values
    - period: Period for the moving average

  ## Returns
    - List of SMA values
  """
  @spec sma(list(), pos_integer()) :: list()
  def sma(data, period) when is_list(data) and is_integer(period) and period > 0 do
    data
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      if Enum.any?(chunk, &is_nil/1) do
        nil
      else
        Enum.sum(chunk) / period
      end
    end)
    |> pad_beginning(period - 1)
  end

  @doc """
  Calculates an Exponential Moving Average (EMA).

  ## Parameters
    - data: List of price values
    - period: Period for the moving average

  ## Returns
    - List of EMA values
  """
  @spec ema(list(), pos_integer()) :: list()
  def ema(data, period) when is_list(data) and is_integer(period) and period > 0 do
    # Filter out nil values for initial calculation
    valid_data = Enum.filter(data, &(not is_nil(&1)))

    if length(valid_data) < period do
      List.duplicate(nil, length(data))
    else
      # Calculate multiplier: 2 / (period + 1)
      multiplier = 2 / (period + 1)

      # Calculate initial SMA
      initial_sma =
        valid_data
        |> Enum.take(period)
        |> Enum.sum()
        |> Kernel./(period)

      # Find the position of the first valid EMA value
      start_pos = Enum.find_index(data, fn val -> not is_nil(val) end) + period - 1

      # Calculate all EMAs
      {emas, _} =
        data
        |> Enum.drop(start_pos + 1)
        |> Enum.reduce({[initial_sma], initial_sma}, fn
          nil, acc -> acc  # Skip nil values
          value, {values, last_ema} ->
            new_ema = (value - last_ema) * multiplier + last_ema
            {[new_ema | values], new_ema}
        end)

      # Pad beginning and return reversed list
      pad_beginning(Enum.reverse(emas), start_pos + 1)
    end
  end
end
