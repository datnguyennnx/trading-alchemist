defmodule Central.Backtest.Indicators.Levels.Fibonacci do
  @moduledoc """
  Implements Fibonacci retracement and extension level calculations.

  Fibonacci levels are used to identify potential support and resistance levels
  based on the Fibonacci sequence. Retracements measure potential reversal levels
  after a price move, while extensions project potential future price targets.
  """

  @doc """
  Calculates Fibonacci retracement levels.

  ## Parameters
    - high: The high price point
    - low: The low price point
    - is_uptrend: Boolean indicating if the trend is up (high > low)

  ## Returns
    - Map with calculated Fibonacci retracement levels from 0% to 100%
    - Common levels are: 0%, 23.6%, 38.2%, 50%, 61.8%, 78.6%, 100%
  """
  def retracement_levels(high, low, is_uptrend \\ true) do
    # Common Fibonacci retracement levels
    levels = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0]

    # Calculate range
    range =
      if is_uptrend do
        Decimal.sub(high, low)
      else
        Decimal.sub(low, high)
      end

    # Calculate levels
    levels_map =
      levels
      |> Enum.map(fn level ->
        decimal_level = Decimal.from_float(level)

        price =
          if is_uptrend do
            # In uptrend: High - (Range * Level)
            Decimal.sub(high, Decimal.mult(range, decimal_level))
          else
            # In downtrend: Low + (Range * Level)
            Decimal.add(high, Decimal.mult(range, decimal_level))
          end

        {level, price}
      end)
      |> Map.new()

    # Return map with calculated levels and original points
    Map.merge(
      %{
        high: high,
        low: low,
        is_uptrend: is_uptrend
      },
      levels_map
    )
  end

  @doc """
  Calculates Fibonacci extension levels.

  ## Parameters
    - start: The starting price point
    - middle: The retracement/correction price point
    - end: The end of the move price point
    - is_uptrend: Boolean indicating if the trend is up

  ## Returns
    - Map with calculated Fibonacci extension levels beyond 100%
    - Common levels are: 1.0, 1.236, 1.382, 1.5, 1.618, 2.0, 2.618, 3.618
  """
  def extension_levels(start, middle, end_point, is_uptrend \\ true) do
    # Common Fibonacci extension levels (beyond 100%)
    levels = [1.0, 1.236, 1.382, 1.5, 1.618, 2.0, 2.618, 3.618]

    # Calculate the first leg range
    first_leg_range =
      if is_uptrend do
        Decimal.sub(middle, start)
      else
        Decimal.sub(start, middle)
      end

    # Calculate price projections
    levels_map =
      levels
      |> Enum.map(fn level ->
        decimal_level = Decimal.from_float(level)

        price =
          if is_uptrend do
            # In uptrend: End + (First Leg Range * Level)
            Decimal.add(end_point, Decimal.mult(first_leg_range, decimal_level))
          else
            # In downtrend: End - (First Leg Range * Level)
            Decimal.sub(end_point, Decimal.mult(first_leg_range, decimal_level))
          end

        {level, price}
      end)
      |> Map.new()

    # Return map with calculated levels and original points
    Map.merge(
      %{
        start: start,
        middle: middle,
        end: end_point,
        is_uptrend: is_uptrend
      },
      levels_map
    )
  end

  @doc """
  Calculates ABCD pattern projection based on Fibonacci ratios.

  ## Parameters
    - a: Price at point A (starting point)
    - b: Price at point B (first correction)
    - c: Price at point C (second push)
    - is_bullish: Boolean indicating if the pattern is bullish (upward)

  ## Returns
    - Map with potential D point projections based on common Fibonacci ratios
  """
  def abcd_projections(a, b, c, is_bullish \\ true) do
    # Common Fibonacci ratios for ABCD patterns
    ratios = [0.618, 0.786, 1.0, 1.272, 1.618]

    # Calculate AB leg
    ab_range = Decimal.sub(b, a) |> Decimal.abs()

    # Calculate projections for D point
    projections =
      ratios
      |> Enum.map(fn ratio ->
        decimal_ratio = Decimal.from_float(ratio)

        # Project D based on direction and CD length (ratio * AB)
        projected_cd = Decimal.mult(ab_range, decimal_ratio)

        d_price =
          if is_bullish do
            Decimal.sub(c, projected_cd)
          else
            Decimal.add(c, projected_cd)
          end

        {ratio, d_price}
      end)
      |> Map.new()

    # Return map with projections and original points
    Map.merge(
      %{
        a: a,
        b: b,
        c: c,
        is_bullish: is_bullish
      },
      projections
    )
  end
end
