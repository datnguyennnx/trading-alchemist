defmodule Central.Backtest.Indicators.Momentum.Stochastic do
  @moduledoc """
  Implements the Stochastic Oscillator indicator.

  The Stochastic Oscillator is a momentum indicator that shows the location of the close
  relative to the high-low range over a set number of periods.
  """

  alias Central.Backtest.Indicators.Calculations.ListOperations
  alias Central.Backtest.Indicators.Calculations.Math

  @doc """
  Calculates the Stochastic Oscillator.

  ## Parameters
    - candles: List of market data candles
    - k_period: Number of periods for %K calculation (typically 14)
    - d_period: Number of periods for %D calculation (typically 3)
    - smooth_k: Periods for smoothing %K (typically 1 or 3)
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of maps containing stochastic values aligned with input candles:
      %{k: value, d: value}
  """
  def stochastic(candles, k_period \\ 14, d_period \\ 3, smooth_k \\ 1, price_key \\ :close)
    when is_list(candles) and is_integer(k_period) and k_period > 0
    and is_integer(d_period) and d_period > 0
    and is_integer(smooth_k) and smooth_k > 0 do

    # Extract price data
    close_prices = ListOperations.extract_key(candles, price_key)
    high_prices = ListOperations.extract_key(candles, :high)
    low_prices = ListOperations.extract_key(candles, :low)

    # Calculate raw %K for each period
    raw_k_values = calculate_raw_k(close_prices, high_prices, low_prices, k_period)

    # Apply smoothing to %K if needed
    smoothed_k =
      if smooth_k > 1 do
        calculate_sma_for_k(raw_k_values, smooth_k)
      else
        raw_k_values
      end

    # Calculate %D (SMA of %K)
    d_values = calculate_sma_for_k(smoothed_k, d_period)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(d_values)
    padded_k = List.duplicate(nil, padding_length) ++ smoothed_k
    padded_d = List.duplicate(nil, padding_length) ++ d_values

    # Pair up the K and D values
    Enum.zip(padded_k, padded_d)
    |> Enum.map(fn
      {nil, _} -> nil
      {_, nil} -> nil
      {k, d} -> %{k: k, d: d}
    end)
  end

  # Calculate the raw %K values
  defp calculate_raw_k(close_prices, high_prices, low_prices, period) do
    # Group data into sliding windows
    closes_chunks = Enum.chunk_every(close_prices, period, 1, :discard)
    highs_chunks = Enum.chunk_every(high_prices, period, 1, :discard)
    lows_chunks = Enum.chunk_every(low_prices, period, 1, :discard)

    # Process each window
    Enum.zip([closes_chunks, highs_chunks, lows_chunks])
    |> Enum.map(fn {closes, highs, lows} ->
      current_close = List.last(closes)
      highest_high = Enum.max_by(highs, &Decimal.to_float/1)
      lowest_low = Enum.min_by(lows, &Decimal.to_float/1)

      # Calculate %K = (Current Close - Lowest Low) / (Highest High - Lowest Low) * 100
      high_low_range = Decimal.sub(highest_high, lowest_low)

      if Decimal.equal?(high_low_range, Decimal.new(0)) do
        # If range is zero, K is 50 by convention
        Decimal.new(50)
      else
        close_low_diff = Decimal.sub(current_close, lowest_low)
        raw_k = Decimal.div(close_low_diff, high_low_range)
        # Convert to 0-100 scale
        Decimal.mult(raw_k, Decimal.new(100))
      end
    end)
  end

  # Calculate a simple moving average for K values
  defp calculate_sma_for_k(k_values, period) when length(k_values) >= period do
    k_values
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      Math.average(chunk)
    end)
  end
  defp calculate_sma_for_k(_k_values, _period), do: []
end
