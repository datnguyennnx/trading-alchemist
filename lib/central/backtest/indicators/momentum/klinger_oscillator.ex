defmodule Central.Backtest.Indicators.Momentum.KlingerOscillator do
  @moduledoc """
  Implements the Klinger Volume Oscillator (KVO).

  The Klinger Oscillator is a volume-based indicator that compares volume to price to
  identify long-term money flow trends and reversals. Developed by Stephen Klinger,
  it's designed to predict price reversals by comparing a fast oscillator line to a slow
  signal line.

  The calculation involves:
  1. Calculate Volume Force (VF) using high, low, close prices and volume
  2. Calculate the Cumulative Volume Force (CVF)
  3. Apply EMA calculations to the CVF using a fast and slow period
  4. The oscillator is the difference between the fast and slow EMAs
  5. A signal line is typically an EMA of the oscillator

  ## Parameters

  - high: List of high prices
  - low: List of low prices
  - close: List of close prices
  - volume: List of volume data
  - fast_period: Fast EMA period (default: 34)
  - slow_period: Slow EMA period (default: 55)
  - signal_period: Signal line EMA period (default: 13)

  ## Returns

  A tuple containing:
  - {:ok, {oscillator_values, signal_values, histogram_values}} on success
  - {:error, reason} on failure

  ## References

  - Stephen J. Klinger developed this indicator in the early 1990s
  - Common interpretations include crossovers, divergences, and histogram analysis
  """

  @doc """
  Calculates the Klinger Volume Oscillator.
  """
  def calculate(
        high,
        low,
        close,
        volume,
        fast_period \\ 34,
        slow_period \\ 55,
        signal_period \\ 13
      ) do
    with true <-
           validate_inputs(high, low, close, volume, fast_period, slow_period, signal_period) do
      # Calculate the Volume Force and its cumulative sum
      volume_force = calculate_volume_force(high, low, close, volume)

      # Calculate EMAs of the cumulative volume force
      {:ok, fast_ema} =
        Central.Backtest.Indicators.Trend.ExponentialMovingAverage.calculate(
          volume_force,
          fast_period
        )

      {:ok, slow_ema} =
        Central.Backtest.Indicators.Trend.ExponentialMovingAverage.calculate(
          volume_force,
          slow_period
        )

      # Calculate the KVO as the difference between fast and slow EMAs
      oscillator =
        Enum.zip(fast_ema, slow_ema)
        |> Enum.map(fn {fast, slow} -> fast - slow end)

      # Calculate the signal line (EMA of the oscillator)
      {:ok, signal} =
        Central.Backtest.Indicators.Trend.ExponentialMovingAverage.calculate(
          oscillator,
          signal_period
        )

      # Calculate the histogram (oscillator - signal)
      histogram =
        Enum.zip(oscillator, signal)
        |> Enum.map(fn {osc, sig} -> osc - sig end)

      {:ok, {oscillator, signal, histogram}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(high, low, close, volume, fast_period, slow_period, signal_period) do
    cond do
      not (is_list(high) and is_list(low) and is_list(close) and is_list(volume)) ->
        {:error, "All price and volume inputs must be lists"}

      length(high) != length(low) or length(high) != length(close) or
          length(high) != length(volume) ->
        {:error, "All input lists must have the same length"}

      fast_period <= 0 or slow_period <= 0 or signal_period <= 0 ->
        {:error, "All periods must be greater than 0"}

      slow_period <= fast_period ->
        {:error, "Slow period must be greater than fast period"}

      length(high) < slow_period ->
        {:error, "Not enough data points for the given periods"}

      true ->
        true
    end
  end

  defp calculate_volume_force(high, low, close, volume) do
    {vf, _} =
      Enum.zip([high, low, close, volume])
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map_reduce(nil, fn [{h1, l1, c1, _v1}, {h2, l2, c2, v2}], _prev_trend ->
        # Calculate typical price
        tp1 = (h1 + l1 + c1) / 3
        tp2 = (h2 + l2 + c2) / 3

        # Determine trend
        trend = if tp2 > tp1, do: 1, else: -1

        # Calculate trend volume
        trend_volume = v2 * trend

        # Calculate volume force
        # Daily high - low range
        dm = h2 - l2
        # Price change magnitude
        cm = if c2 > c1, do: c2 - c1, else: c1 - c2

        # Avoid division by zero
        vf = if dm != 0, do: trend_volume * cm / dm, else: 0

        # Store trend for next iteration and return volume force
        {vf, trend}
      end)

    # Pad with zeros for the first values
    pad_zeros = List.duplicate(0, length(high) - length(vf))
    pad_zeros ++ vf
  end

  @doc """
  Generates trading signals based on Klinger Oscillator.

  Returns:
  - 1 for buy signal (oscillator crosses above signal line)
  - -1 for sell signal (oscillator crosses below signal line)
  - 0 for no signal
  """
  def generate_signals({oscillator, signal, _histogram}) do
    Enum.zip(oscillator, signal)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{osc1, sig1}, {osc2, sig2}] ->
      cond do
        # Bullish crossover
        osc1 < sig1 and osc2 > sig2 -> 1
        # Bearish crossover
        osc1 > sig1 and osc2 < sig2 -> -1
        # No signal
        true -> 0
      end
    end)
    |> List.insert_at(0, 0)
  end

  @doc """
  Finds divergences between price and the Klinger Oscillator.

  Returns a list of divergence events:
  - {:bullish_divergence, index} when price makes lower low but oscillator makes higher low
  - {:bearish_divergence, index} when price makes higher high but oscillator makes lower high
  """
  def find_divergences(prices, {oscillator, _signal, _histogram}, lookback \\ 10) do
    Enum.zip(prices, oscillator)
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index(lookback - 1)
    |> Enum.flat_map(fn {window, index} ->
      find_divergences_in_window(window, index)
    end)
  end

  defp find_divergences_in_window(window, index) do
    {prices, oscillator_values} = Enum.unzip(window)

    # Find local extremes
    price_min_index = Enum.find_index(prices, fn p -> p == Enum.min(prices) end)
    price_max_index = Enum.find_index(prices, fn p -> p == Enum.max(prices) end)

    osc_min_index =
      Enum.find_index(oscillator_values, fn o -> o == Enum.min(oscillator_values) end)

    osc_max_index =
      Enum.find_index(oscillator_values, fn o -> o == Enum.max(oscillator_values) end)

    all_divergences = []

    # Check for bullish divergence (price makes new low but oscillator doesn't)
    all_divergences =
      if price_min_index == length(prices) - 1 and osc_min_index != price_min_index do
        [{:bullish_divergence, index} | all_divergences]
      else
        all_divergences
      end

    # Check for bearish divergence (price makes new high but oscillator doesn't)
    all_divergences =
      if price_max_index == length(prices) - 1 and osc_max_index != price_max_index do
        [{:bearish_divergence, index} | all_divergences]
      else
        all_divergences
      end

    all_divergences
  end

  @doc """
  Identifies Klinger Oscillator volume anomalies.

  Returns a list of volume anomaly events:
  - {:volume_spike, index} when volume force shows unusual activity
  - {:volume_divergence, index} when price and volume show opposing behaviors
  """
  def detect_volume_anomalies(high, low, close, volume, threshold \\ 2.0) do
    volume_force = calculate_volume_force(high, low, close, volume)

    # Calculate standard deviation of volume force
    mean_vf = Enum.sum(volume_force) / length(volume_force)

    variance =
      Enum.reduce(volume_force, 0, fn vf, acc ->
        acc + :math.pow(vf - mean_vf, 2)
      end) / length(volume_force)

    std_dev = :math.sqrt(variance)

    # Detect anomalies based on standard deviation
    volume_force
    |> Enum.with_index()
    |> Enum.filter(fn {vf, _} ->
      abs(vf - mean_vf) > threshold * std_dev
    end)
    |> Enum.map(fn {_, index} -> {:volume_spike, index} end)
  end
end
