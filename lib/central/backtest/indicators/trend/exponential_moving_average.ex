defmodule Central.Backtest.Indicators.Trend.ExponentialMovingAverage do
  @moduledoc """
  Implements exponential moving average calculations.

  This module provides a standalone implementation of EMA calculation
  for use by other indicators. While MovingAverage also provides EMA
  functionality, this module uses a consistent {:ok, result} return pattern.
  """

  alias Central.Backtest.Indicators.Calculations.Math

  @doc """
  Calculates an Exponential Moving Average (EMA) for a list of values.

  ## Parameters
    - values: List of numeric values
    - period: Number of periods for the EMA

  ## Returns
    - {:ok, result} with the list of EMA values
    - {:error, reason} if calculation fails
  """
  def calculate(values, period) when is_list(values) and is_integer(period) and period > 0 do
    if length(values) < period do
      {:error, "Insufficient data: need at least #{period} values"}
    else
      # Calculate multiplier: 2 / (period + 1)
      multiplier = Decimal.div(Decimal.new(2), Decimal.add(Decimal.new(period), Decimal.new(1)))

      # Use SMA as first value
      first_sma = Enum.take(values, period) |> Math.average()

      # Calculate EMA
      ema_values =
        values
        |> Enum.drop(period - 1)
        |> calculate_ema(multiplier, first_sma, [])
        |> Enum.reverse()

      # Add nil values at the beginning to align with input
      result = List.duplicate(nil, period - 1) ++ ema_values

      {:ok, result}
    end
  end

  defp calculate_ema([], _multiplier, _prev_ema, results), do: results

  defp calculate_ema([price | rest], multiplier, prev_ema, results) do
    # EMA = Price * multiplier + Previous EMA * (1 - multiplier)
    new_ema =
      Decimal.add(
        Decimal.mult(price, multiplier),
        Decimal.mult(prev_ema, Decimal.sub(Decimal.new(1), multiplier))
      )

    calculate_ema(rest, multiplier, new_ema, [new_ema | results])
  end
end
