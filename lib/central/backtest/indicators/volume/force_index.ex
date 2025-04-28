defmodule Central.Backtest.Indicators.Volume.ForceIndex do
  @moduledoc """
  Implements the Force Index indicator.

  Force Index is a volume-based oscillator that measures the force (or power)
  behind price movements. It combines price change and volume to assess the
  buying and selling pressure.

  The calculation involves:
  1. Calculate the price change (current close - previous close)
  2. Multiply the price change by volume
  3. Apply smoothing with an exponential moving average

  ## Parameters

  - close: List of closing prices
  - volume: List of volume values
  - period: Number of periods for smoothing (default: 13)

  ## Returns

  A tuple containing:
  - {:ok, force_index_values} on success
  - {:error, reason} on failure
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates the Force Index indicator.
  """
  def calculate(close, volume, period \\ 13) do
    with true <- validate_inputs(close, volume, period),
         raw_force_index <- calculate_raw_force_index(close, volume),
         smoothed_force_index <- MovingAverage.ema(raw_force_index, period) do
      {:ok, smoothed_force_index}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(close, volume, period) do
    cond do
      not is_list(close) or not is_list(volume) ->
        {:error, "Inputs must be lists"}

      length(close) != length(volume) ->
        {:error, "Input lists must have the same length"}

      period <= 0 ->
        {:error, "Period must be greater than 0"}

      true ->
        true
    end
  end

  defp calculate_raw_force_index(close, volume) do
    close
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] -> curr - prev end)
    |> Enum.zip(Enum.drop(volume, 1))
    |> Enum.map(fn {price_change, vol} -> price_change * vol end)
    |> List.insert_at(0, 0)
  end

  @doc """
  Calculates multiple Force Index periods for different timeframes.

  Returns a map with keys representing different periods:
  - short_term: Force Index with period 2 (reflects short-term changes)
  - medium_term: Force Index with period 13 (reflects intermediate trends)
  - long_term: Force Index with period specified (default 50, reflects major trends)
  """
  def calculate_multi_timeframe(close, volume, long_period \\ 50) do
    with true <- validate_inputs(close, volume, 2),
         raw_force_index <- calculate_raw_force_index(close, volume),
         short_term <- MovingAverage.ema(raw_force_index, 2),
         medium_term <- MovingAverage.ema(raw_force_index, 13),
         long_term <- MovingAverage.ema(raw_force_index, long_period) do
      {:ok,
       %{
         short_term: short_term,
         medium_term: medium_term,
         long_term: long_term
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates trading signals based on Force Index values.

  Returns:
  - 1 for buy signal (Force Index crosses above zero)
  - -1 for sell signal (Force Index crosses below zero)
  - 0 for no signal
  """
  def generate_signals(force_index) do
    force_index
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      cond do
        prev <= 0 and curr > 0 -> 1
        prev >= 0 and curr < 0 -> -1
        true -> 0
      end
    end)
    |> List.insert_at(0, 0)
  end

  @doc """
  Identifies divergences between price and Force Index.

  Returns a list of divergence events:
  - {:bullish_divergence, index} when price makes lower low but Force Index makes higher low
  - {:bearish_divergence, index} when price makes higher high but Force Index makes lower high
  """
  def find_divergences(high, low, force_index, lookback \\ 5) do
    Enum.zip([high, low, force_index])
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.flat_map(fn {window, index} ->
      find_divergences_in_window(window, index)
    end)
  end

  defp find_divergences_in_window(window, index) do
    {prices, force_index_values} = Enum.unzip(window)

    # Start with empty list
    divergences = []

    # Check for bullish divergence (price makes lower low but force index doesn't)
    divergences =
      if Enum.min(prices) == List.last(prices) and
           Enum.min(force_index_values) != List.last(force_index_values) do
        [{:bullish_divergence, index} | divergences]
      else
        divergences
      end

    # Check for bearish divergence (price makes higher high but force index doesn't)
    divergences =
      if Enum.max(prices) == List.last(prices) and
           Enum.max(force_index_values) != List.last(force_index_values) do
        [{:bearish_divergence, index} | divergences]
      else
        divergences
      end

    divergences
  end

  @doc """
  Analyzes Force Index changes to identify trend strength.

  Returns a map with:
  - :trend - :bullish, :bearish, or :neutral
  - :strength - value from 0 to 1 indicating trend strength
  - :reversal_potential - value from 0 to 1 indicating potential for reversal
  """
  def analyze_trend_strength(force_index, lookback \\ 10) do
    force_index
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.map(fn {window, index} ->
      _avg = Enum.sum(window) / length(window)
      positive_count = Enum.count(window, &(&1 > 0))
      _negative_count = lookback - positive_count
      ratio = positive_count / lookback

      cond do
        ratio > 0.7 -> {:strong_bullish, index}
        ratio > 0.5 -> {:moderate_bullish, index}
        ratio < 0.3 -> {:strong_bearish, index}
        ratio < 0.5 -> {:moderate_bearish, index}
        true -> {:neutral, index}
      end
    end)
  end
end
