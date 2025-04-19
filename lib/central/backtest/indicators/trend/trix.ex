defmodule Central.Backtest.Indicators.Trend.Trix do
  @moduledoc """
  Implements the TRIX (Triple Exponential Average) indicator.

  TRIX is a momentum oscillator that shows the percentage rate of change of a triple-smoothed exponential moving average.
  It is used to identify overbought and oversold conditions, as well as to generate buy and sell signals.

  The calculation involves:
  1. Calculate a single EMA of the price
  2. Calculate a double EMA of the first EMA
  3. Calculate a triple EMA of the second EMA
  4. Calculate the percentage rate of change of the triple EMA

  ## Parameters

  - prices: List of price values (typically closing prices)
  - period: Number of periods to use for smoothing (default: 15)

  ## Returns

  A tuple containing:
  - {:ok, %{trix: trix_values, signal: signal_values}} on success
  - {:error, reason} on failure
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates the TRIX indicator.
  """
  def calculate(prices, period \\ 15) do
    with true <- validate_inputs(prices, period),
         triple_ema <- calculate_triple_ema(prices, period),
         trix <- calculate_trix_values(triple_ema),
         signal <- calculate_signal_line(trix, 9) do
      {:ok, %{trix: trix, signal: signal}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(prices, period) do
    cond do
      not is_list(prices) ->
        {:error, "Prices must be a list"}
      length(prices) < period * 3 ->
        {:error, "Not enough data points for the given period"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      true ->
        true
    end
  end

  defp calculate_triple_ema(prices, period) do
    prices
    |> MovingAverage.ema(period)
    |> MovingAverage.ema(period)
    |> MovingAverage.ema(period)
  end

  defp calculate_trix_values(triple_ema) do
    triple_ema
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      if prev == 0, do: 0, else: 100 * (curr - prev) / prev
    end)
    |> List.insert_at(0, 0)
  end

  defp calculate_signal_line(trix, signal_period) do
    trix
    |> Enum.chunk_every(signal_period, 1, :discard)
    |> Enum.map(&Enum.sum/1)
    |> Enum.map(&(&1 / signal_period))
    |> List.insert_at(0, 0)
  end

  @doc """
  Generates trading signals based on TRIX values.

  ## Parameters
    - trix_result: Result map from calculate/2
    - zero_line_crossover: Whether to include zero line crossovers in signals

  ## Returns
    - {:ok, signals} where signals is a list of:
      - 1 for buy signal (TRIX crosses above signal line)
      - -1 for sell signal (TRIX crosses below signal line)
      - 0 for no signal
  """
  def generate_signals(%{trix: trix, signal: signal}, zero_line_crossover \\ true) do
    signals =
      Enum.zip(trix, signal)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [{prev_trix, prev_signal}, {curr_trix, curr_signal}] ->
        cond do
          prev_trix < prev_signal and curr_trix > curr_signal -> 1
          prev_trix > prev_signal and curr_trix < curr_signal -> -1
          true -> 0
        end
      end)
      |> List.insert_at(0, 0)

    # Add zero-line crossover signals if requested
    signals =
      if zero_line_crossover do
        zero_crossovers =
          trix
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [prev, curr] ->
            cond do
              prev < 0 and curr >= 0 -> 1      # Crossed above zero (bullish)
              prev > 0 and curr <= 0 -> -1     # Crossed below zero (bearish)
              true -> 0                        # No zero-cross
            end
          end)
          |> List.insert_at(0, 0)

        # Combine signal line crossovers with zero-line crossovers
        # Prioritize signal line crossovers when both occur
        Enum.zip(signals, zero_crossovers)
        |> Enum.map(fn {signal, zero_cross} ->
          if signal != 0, do: signal, else: zero_cross
        end)
      else
        signals
      end

    {:ok, signals}
  end

  @doc """
  Convenience function for calculating TRIX with custom parameters.

  ## Parameters
    - candles: List of OHLCV data
    - period: Number of periods for calculation (default: 15)
    - signal_period: Number of periods for signal line (default: 9)
    - price_key: Key to use for price data (default: :close)

  ## Returns
    - {:ok, result} where result is a map with :trix and :signal values
  """
  def trix(candles, period \\ 15, signal_period \\ 9, price_key \\ :close) do
    prices = Enum.map(candles, &Map.get(&1, price_key))

    with {:ok, %{trix: trix_values} = result} <- calculate(prices, period) do
      # If signal period is different from default, recalculate signal line
      if signal_period != 9 do
        signal = calculate_signal_line(trix_values, signal_period)
        {:ok, %{result | signal: signal}}
      else
        {:ok, result}
      end
    end
  end
end
