defmodule Central.Backtest.Indicators.Momentum.UltimateOscillator do
  @moduledoc """
  Implements the Ultimate Oscillator indicator.

  The Ultimate Oscillator is a momentum oscillator designed to capture momentum
  across three different timeframes to reduce false signals and provide a more
  balanced view of market conditions.

  The calculation involves:
  1. Calculate buying pressure (BP) = Close - Minimum(Low, Prior Close)
  2. Calculate true range (TR) = Maximum(High, Prior Close) - Minimum(Low, Prior Close)
  3. Calculate average BP and TR for three different periods
  4. Calculate the ratios of BP/TR for each period
  5. Apply weighted average to these ratios to get Ultimate Oscillator

  ## Parameters

  - high: List of high prices
  - low: List of low prices
  - close: List of close prices
  - short_period: Short-term period (default: 7)
  - medium_period: Medium-term period (default: 14)
  - long_period: Long-term period (default: 28)
  - weights: Weights for the three components (default: [4, 2, 1])

  ## Returns

  A tuple containing:
  - {:ok, ultimate_oscillator_values} on success
  - {:error, reason} on failure
  """

  @doc """
  Calculates the Ultimate Oscillator.
  """
  def calculate(
        high,
        low,
        close,
        short_period \\ 7,
        medium_period \\ 14,
        long_period \\ 28,
        weights \\ [4, 2, 1]
      ) do
    with true <-
           validate_inputs(high, low, close, short_period, medium_period, long_period, weights),
         bp <- calculate_buying_pressure(close, low),
         tr <- calculate_true_range(high, low, close),
         avg_bp_short <- calculate_average(bp, short_period),
         avg_tr_short <- calculate_average(tr, short_period),
         avg_bp_medium <- calculate_average(bp, medium_period),
         avg_tr_medium <- calculate_average(tr, medium_period),
         avg_bp_long <- calculate_average(bp, long_period),
         avg_tr_long <- calculate_average(tr, long_period),
         [weight_short, weight_medium, weight_long] <- weights do
      # Calculate ratios and ultimate oscillator
      ratios_short = safe_divide(avg_bp_short, avg_tr_short)
      ratios_medium = safe_divide(avg_bp_medium, avg_tr_medium)
      ratios_long = safe_divide(avg_bp_long, avg_tr_long)

      # Calculate Ultimate Oscillator with weights
      uo =
        Enum.zip([ratios_short, ratios_medium, ratios_long])
        |> Enum.map(fn {short, medium, long} ->
          numerator = short * weight_short + medium * weight_medium + long * weight_long
          denominator = weight_short + weight_medium + weight_long
          numerator / denominator * 100
        end)

      {:ok, uo}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(high, low, close, short_period, medium_period, long_period, weights) do
    cond do
      not is_list(high) or not is_list(low) or not is_list(close) ->
        {:error, "Inputs must be lists"}

      length(high) != length(low) or length(low) != length(close) ->
        {:error, "Input lists must have the same length"}

      short_period <= 0 or medium_period <= 0 or long_period <= 0 ->
        {:error, "Periods must be greater than 0"}

      short_period >= medium_period or medium_period >= long_period ->
        {:error, "Periods must be in ascending order: short < medium < long"}

      length(weights) != 3 ->
        {:error, "Weights must be a list of 3 values"}

      Enum.any?(weights, fn w -> w <= 0 end) ->
        {:error, "Weights must be positive values"}

      length(close) < long_period + 1 ->
        {:error, "Not enough data points for the given periods"}

      true ->
        true
    end
  end

  defp calculate_buying_pressure(close, low) do
    # First value is nil (no prior close)
    [_ | rest_close] = close
    prior_close = [nil | Enum.drop(close, -1)]

    Enum.zip([rest_close, Enum.drop(low, 1), Enum.drop(prior_close, 1)])
    |> Enum.map(fn {c, l, pc} ->
      if pc == nil, do: 0, else: c - min(l, pc)
    end)
    # Insert placeholder for first value
    |> List.insert_at(0, 0)
  end

  defp calculate_true_range(high, low, close) do
    # First value is high - low (no prior close)
    [first_high | rest_high] = high
    [first_low | rest_low] = low
    prior_close = [nil | Enum.drop(close, -1)]

    first_tr = first_high - first_low

    rest_tr =
      Enum.zip([rest_high, rest_low, Enum.drop(prior_close, 1)])
      |> Enum.map(fn {h, l, pc} ->
        if pc == nil do
          # Just high - low for first candle
          h - l
        else
          max(h, pc) - min(l, pc)
        end
      end)

    [first_tr | rest_tr]
  end

  defp calculate_average(values, period) do
    values
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk -> Enum.sum(chunk) end)
    |> pad_with_zeros(length(values))
  end

  defp safe_divide(numerators, denominators) do
    Enum.zip(numerators, denominators)
    |> Enum.map(fn {num, denom} ->
      if denom == 0, do: 0, else: num / denom
    end)
  end

  defp pad_with_zeros(values, original_length) do
    padding_length = original_length - length(values)

    if padding_length > 0 do
      List.duplicate(0, padding_length) ++ values
    else
      values
    end
  end

  @doc """
  Generates trading signals based on Ultimate Oscillator.

  Returns:
  - 1 for buy signal (bullish divergence or oversold bounce)
  - -1 for sell signal (bearish divergence or overbought reversal)
  - 0 for no signal
  """
  def generate_signals(uo, overbought \\ 70, oversold \\ 30) do
    uo
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.map(fn [prev2, prev1, curr] ->
      cond do
        # Bullish divergence or oversold bounce
        prev2 < oversold and prev1 < oversold and curr > prev1 and curr > oversold ->
          1

        # Bearish divergence or overbought reversal
        prev2 > overbought and prev1 > overbought and curr < prev1 and curr < overbought ->
          -1

        true ->
          0
      end
    end)
    |> pad_with_zeros(length(uo))
  end

  @doc """
  Finds divergences between price and Ultimate Oscillator.

  Returns a list of divergence events:
  - {:bullish_divergence, index} when price makes lower low but UO makes higher low
  - {:bearish_divergence, index} when price makes higher high but UO makes lower high
  """
  def find_divergences(high, low, uo, lookback \\ 5) do
    Enum.zip([high, low, uo])
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.flat_map(fn {window, index} ->
      find_divergences_in_window(window, index)
    end)
  end

  defp find_divergences_in_window(window, index) do
    {highs, lows, uo_values} =
      window
      |> Enum.reduce({[], [], []}, fn {h, l, u}, {hs, ls, us} ->
        {[h | hs], [l | ls], [u | us]}
      end)
      |> then(fn {hs, ls, us} -> {Enum.reverse(hs), Enum.reverse(ls), Enum.reverse(us)} end)

    all_divergences = []

    # Check for bullish divergence
    all_divergences =
      if Enum.min(lows) == List.last(lows) and
           Enum.min(uo_values) != List.last(uo_values) and
           Enum.min(uo_values) < List.last(uo_values) do
        [{:bullish_divergence, index} | all_divergences]
      else
        all_divergences
      end

    # Check for bearish divergence
    all_divergences =
      if Enum.max(highs) == List.last(highs) and
           Enum.max(uo_values) != List.last(uo_values) and
           Enum.max(uo_values) > List.last(uo_values) do
        [{:bearish_divergence, index} | all_divergences]
      else
        all_divergences
      end

    all_divergences
  end
end
