defmodule Central.Backtest.Indicators.Momentum.Tsi do
  @moduledoc """
  Implements the True Strength Index (TSI) indicator.

  TSI is a momentum oscillator that uses double smoothing of price changes
  to filter out market noise and identify trend direction and strength.

  The calculation involves:
  1. Calculate price changes
  2. Apply a first exponential smoothing to the price changes and absolute price changes
  3. Apply a second exponential smoothing to the results
  4. Calculate the ratio of the double-smoothed price changes to the double-smoothed absolute price changes
  5. Multiply by 100 to get a percentage

  ## Parameters

  - prices: List of price values (typically closing prices)
  - long_period: Number of periods for the first smoothing (default: 25)
  - short_period: Number of periods for the second smoothing (default: 13)
  - signal_period: Number of periods for the signal line (default: 7)

  ## Returns

  A tuple containing:
  - {:ok, %{tsi: tsi_values, signal: signal_values}} on success
  - {:error, reason} on failure
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage
  alias Central.Backtest.Indicators.Calculations.ListOperations

  @doc """
  Calculates the True Strength Index.
  """
  def calculate(
        candles,
        long_period \\ 25,
        short_period \\ 13,
        signal_period \\ 7,
        price_key \\ :close
      )
      when is_list(candles) do
    prices =
      candles
      |> Enum.map(&Map.get(&1, price_key))

    with true <- validate_inputs(prices, long_period, short_period, signal_period),
         price_changes <- calculate_price_changes(prices),
         abs_price_changes <- Enum.map(price_changes, &abs/1),
         first_smoothed_momentum <- exponential_smoothing(price_changes, long_period),
         first_smoothed_abs_momentum <- exponential_smoothing(abs_price_changes, long_period),
         double_smoothed_momentum <- exponential_smoothing(first_smoothed_momentum, short_period),
         double_smoothed_abs_momentum <-
           exponential_smoothing(first_smoothed_abs_momentum, short_period),
         tsi <- calculate_tsi_values(double_smoothed_momentum, double_smoothed_abs_momentum),
         signal <- calculate_signal_line(tsi, signal_period) do
      {:ok, %{tsi: tsi, signal: signal}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(prices, long_period, short_period, signal_period) do
    cond do
      not is_list(prices) ->
        {:error, "Prices must be a list"}

      length(prices) < long_period + short_period ->
        {:error, "Not enough data points for the given periods"}

      long_period <= 0 or short_period <= 0 or signal_period <= 0 ->
        {:error, "Periods must be greater than 0"}

      true ->
        true
    end
  end

  defp calculate_price_changes(prices) do
    prices
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] -> curr - prev end)
    |> List.insert_at(0, 0)
  end

  defp exponential_smoothing(values, period) do
    alpha = 2 / (period + 1)

    values
    |> Enum.reduce([], fn
      value, [] -> [value]
      value, [prev | _] = acc -> [prev + alpha * (value - prev) | acc]
    end)
    |> Enum.reverse()
  end

  defp calculate_tsi_values(double_smoothed_momentum, double_smoothed_abs_momentum) do
    Enum.zip(double_smoothed_momentum, double_smoothed_abs_momentum)
    |> Enum.map(fn {momentum, abs_momentum} ->
      if abs_momentum == 0, do: 0, else: 100 * momentum / abs_momentum
    end)
  end

  defp calculate_signal_line(tsi, signal_period) do
    tsi
    |> MovingAverage.ema(signal_period)
  end

  @doc """
  Generates trading signals based on TSI values.

  Returns:
  - {:ok, signals} where signals is a list of:
    - 1 for buy signal (TSI crosses above signal line)
    - -1 for sell signal (TSI crosses below signal line)
    - 0 for no signal
  """
  def generate_signals(%{tsi: tsi, signal: signal}) do
    signals =
      Enum.zip(tsi, signal)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [{prev_tsi, prev_signal}, {curr_tsi, curr_signal}] ->
        cond do
          prev_tsi < prev_signal and curr_tsi > curr_signal -> 1
          prev_tsi > prev_signal and curr_tsi < curr_signal -> -1
          true -> 0
        end
      end)
      |> List.insert_at(0, 0)

    {:ok, signals}
  end

  @doc """
  Identifies divergences between price and TSI.

  Returns {:ok, divergences} where divergences is a list of:
  - {:bullish_divergence, index} when price makes lower low but TSI makes higher low
  - {:bearish_divergence, index} when price makes higher high but TSI makes lower high
  """
  def find_divergences(candles, %{tsi: tsi}, lookback \\ 5) do
    high = Enum.map(candles, &Map.get(&1, :high))
    low = Enum.map(candles, &Map.get(&1, :low))

    result =
      Enum.zip([high, low, tsi])
      |> Enum.chunk_every(lookback, 1, :discard)
      |> Enum.with_index()
      |> Enum.flat_map(fn {window, index} ->
        find_divergences_in_window(window, index)
      end)

    {:ok, result}
  end

  defp find_divergences_in_window(window, index) do
    {highs, lows, tsi_values} =
      window
      |> ListOperations.unzip3()

    # Use different variable name for divergences to avoid shadowing
    divergence_list = []

    # Check for bullish divergence
    divergence_list =
      if Enum.min(lows) == List.last(lows) and
           Enum.min(tsi_values) != List.last(tsi_values) and
           Enum.min(tsi_values) < List.last(tsi_values) do
        [{:bullish_divergence, index} | divergence_list]
      else
        divergence_list
      end

    # Check for bearish divergence
    divergence_list =
      if Enum.max(highs) == List.last(highs) and
           Enum.max(tsi_values) != List.last(tsi_values) and
           Enum.max(tsi_values) > List.last(tsi_values) do
        [{:bearish_divergence, index} | divergence_list]
      else
        divergence_list
      end

    divergence_list
  end
end
