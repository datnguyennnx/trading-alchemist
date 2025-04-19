defmodule Central.Backtest.Indicators.Volatility.Atr do
  @moduledoc """
  Implements the Average True Range (ATR) indicator.

  ATR is a volatility indicator that measures market volatility by
  decomposing the entire range of an asset price for a specific period.
  """

  alias Central.Backtest.Indicators.Calculations.Math

  @doc """
  Calculates the Average True Range (ATR).

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the ATR calculation (typically 14)

  ## Returns
    - List of ATR values aligned with the input candles
      (first period values are nil)
  """
  def atr(candles, period \\ 14) when is_list(candles) and is_integer(period) and period > 0 do
    # Calculate true ranges
    true_ranges = calculate_true_ranges(candles)

    # For the first ATR value, use simple average of the first 'period' true ranges
    first_tr_values = Enum.take(true_ranges, period)
    first_atr = Math.average(first_tr_values)

    # Calculate subsequent ATR values using the Wilder's smoothing method
    rest_tr_values = Enum.drop(true_ranges, period)
    rest_atr_values = calculate_smoothed_atr(rest_tr_values, first_atr, period, [])

    # Combine the results and align with input data
    all_atr_values = [first_atr | rest_atr_values]
    List.duplicate(nil, period - 1) ++ all_atr_values
  end

  @doc """
  Calculates true ranges for a list of candles.

  ## Parameters
    - candles: List of market data candles

  ## Returns
    - List of true range values (length is one less than input)
  """
  def calculate_true_ranges(candles) when is_list(candles) and length(candles) > 1 do
    Enum.chunk_every(candles, 2, 1, :discard)
    |> Enum.map(fn [current, previous] ->
      # True Range is the greatest of:
      # 1. Current High - Current Low
      # 2. |Current High - Previous Close|
      # 3. |Current Low - Previous Close|

      high_low = Decimal.sub(current.high, current.low)
      high_prev_close = Decimal.sub(current.high, previous.close) |> Decimal.abs()
      low_prev_close = Decimal.sub(current.low, previous.close) |> Decimal.abs()

      # Find the maximum
      Enum.max_by([high_low, high_prev_close, low_prev_close], &Decimal.to_float/1)
    end)
  end

  # Recursive function to calculate ATR using Wilder's smoothing
  defp calculate_smoothed_atr([], _prev_atr, _period, results), do: Enum.reverse(results)

  defp calculate_smoothed_atr([tr | rest], prev_atr, period, results) do
    # Wilder's smoothing: ATR = ((prev_ATR * (period - 1)) + current_TR) / period
    new_atr = Decimal.div(
      Decimal.add(
        Decimal.mult(prev_atr, Decimal.new(period - 1)),
        tr
      ),
      Decimal.new(period)
    )

    calculate_smoothed_atr(rest, new_atr, period, [new_atr | results])
  end
end
