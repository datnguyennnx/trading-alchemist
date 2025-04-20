defmodule Central.Backtest.Indicators.Calculations.Normalization do
  @moduledoc """
  Normalization functions for technical indicators.

  This module provides utility functions for normalizing data,
  including scaling, standardization, and other transformations.
  """

  alias Central.Backtest.Indicators.Calculations.Math

  @doc """
  Normalizes values to a 0-1 range.

  ## Parameters
    - values: List of Decimal values to normalize

  ## Returns
    - List of normalized Decimal values between 0 and 1
  """
  def normalize_to_range(values) when is_list(values) and length(values) > 0 do
    min_value = Enum.min_by(values, &Decimal.to_float/1)
    max_value = Enum.max_by(values, &Decimal.to_float/1)
    range = Decimal.sub(max_value, min_value)

    if Decimal.equal?(range, Decimal.new(0)) do
      List.duplicate(Decimal.new("0.5"), length(values))
    else
      Enum.map(values, fn value ->
        Decimal.div(Decimal.sub(value, min_value), range)
      end)
    end
  end

  @doc """
  Normalizes values using Z-score (mean 0, standard deviation 1).

  ## Parameters
    - values: List of Decimal values to normalize

  ## Returns
    - List of normalized Decimal values with mean 0 and std dev 1
  """
  def normalize_z_score(values) when is_list(values) and length(values) > 0 do
    # Calculate mean
    mean =
      Enum.reduce(values, Decimal.new(0), &Decimal.add/2)
      |> Decimal.div(Decimal.new(length(values)))

    # Calculate standard deviation
    sum_of_squares =
      Enum.reduce(values, Decimal.new(0), fn value, acc ->
        diff = Decimal.sub(value, mean)
        squared_diff = Decimal.mult(diff, diff)
        Decimal.add(acc, squared_diff)
      end)

    variance = Decimal.div(sum_of_squares, Decimal.new(length(values)))
    std_dev = Math.decimal_sqrt(variance)

    # Handle case where std_dev is 0
    if Decimal.equal?(std_dev, Decimal.new(0)) do
      List.duplicate(Decimal.new(0), length(values))
    else
      # Normalize each value
      Enum.map(values, fn value ->
        Decimal.div(Decimal.sub(value, mean), std_dev)
      end)
    end
  end

  @doc """
  Scales values to a specific range.

  ## Parameters
    - values: List of Decimal values to scale
    - min_target: Minimum value of target range
    - max_target: Maximum value of target range

  ## Returns
    - List of scaled Decimal values between min_target and max_target
  """
  def scale_to_range(values, min_target, max_target) when is_list(values) and length(values) > 0 do
    normalized = normalize_to_range(values)
    range = Decimal.sub(max_target, min_target)

    Enum.map(normalized, fn norm_value ->
      Decimal.add(min_target, Decimal.mult(norm_value, range))
    end)
  end
end
