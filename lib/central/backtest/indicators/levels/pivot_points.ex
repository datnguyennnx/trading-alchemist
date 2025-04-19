defmodule Central.Backtest.Indicators.Levels.PivotPoints do
  @moduledoc """
  Implements various pivot point calculation methods.

  Pivot points are used to determine levels of support and resistance
  and are particularly useful for short-term trading.
  """

  @doc """
  Calculates standard pivot points.

  ## Parameters
    - candle: A single candle representing the period (typically daily)
      containing high, low, and close prices

  ## Returns
    - Map with calculated pivot points
      %{
        pivot: value,
        r1: value, r2: value, r3: value,
        s1: value, s2: value, s3: value
      }
  """
  def standard(%{high: high, low: low, close: close}) do
    # Calculate the pivot point (P)
    pivot = Decimal.div(
      Decimal.add(Decimal.add(high, low), close),
      Decimal.new(3)
    )

    # Calculate resistance levels
    r1 = Decimal.mult(Decimal.new(2), pivot) |> Decimal.sub(low)
    r2 = Decimal.add(pivot, Decimal.sub(high, low))
    r3 = Decimal.add(high, Decimal.mult(Decimal.new(2), Decimal.sub(pivot, low)))

    # Calculate support levels
    s1 = Decimal.mult(Decimal.new(2), pivot) |> Decimal.sub(high)
    s2 = Decimal.sub(pivot, Decimal.sub(high, low))
    s3 = Decimal.sub(low, Decimal.mult(Decimal.new(2), Decimal.sub(high, pivot)))

    %{
      pivot: pivot,
      r1: r1, r2: r2, r3: r3,
      s1: s1, s2: s2, s3: s3
    }
  end

  @doc """
  Calculates Fibonacci pivot points.

  ## Parameters
    - candle: A single candle representing the period (typically daily)
      containing high, low, and close prices

  ## Returns
    - Map with calculated Fibonacci pivot points
      %{
        pivot: value,
        r1: value, r2: value, r3: value,
        s1: value, s2: value, s3: value
      }
  """
  def fibonacci(%{high: high, low: low, close: close}) do
    # Calculate the pivot point (P) - same as standard
    pivot = Decimal.div(
      Decimal.add(Decimal.add(high, low), close),
      Decimal.new(3)
    )

    # Fibonacci ratios
    fib_0_382 = Decimal.from_float(0.382)
    fib_0_618 = Decimal.from_float(0.618)
    fib_1_000 = Decimal.new(1)

    # Calculate range
    range = Decimal.sub(high, low)

    # Calculate resistance levels
    r1 = Decimal.add(pivot, Decimal.mult(range, fib_0_382))
    r2 = Decimal.add(pivot, Decimal.mult(range, fib_0_618))
    r3 = Decimal.add(pivot, Decimal.mult(range, fib_1_000))

    # Calculate support levels
    s1 = Decimal.sub(pivot, Decimal.mult(range, fib_0_382))
    s2 = Decimal.sub(pivot, Decimal.mult(range, fib_0_618))
    s3 = Decimal.sub(pivot, Decimal.mult(range, fib_1_000))

    %{
      pivot: pivot,
      r1: r1, r2: r2, r3: r3,
      s1: s1, s2: s2, s3: s3
    }
  end

  @doc """
  Calculates Camarilla pivot points.

  ## Parameters
    - candle: A single candle representing the period (typically daily)
      containing high, low, and close prices

  ## Returns
    - Map with calculated Camarilla pivot points
      %{
        pivot: value,
        r1: value, r2: value, r3: value, r4: value,
        s1: value, s2: value, s3: value, s4: value
      }
  """
  def camarilla(%{high: high, low: low, close: close}) do
    # Calculate range
    range = Decimal.sub(high, low)

    # Camarilla multipliers
    mult_1_1 = Decimal.from_float(1.1)
    mult_1_2 = Decimal.from_float(1.2)
    mult_1_3 = Decimal.from_float(1.3)
    mult_1_5 = Decimal.from_float(1.5)

    # Calculate resistance levels
    r4 = Decimal.add(close, Decimal.mult(range, mult_1_5))
    r3 = Decimal.add(close, Decimal.mult(range, mult_1_3))
    r2 = Decimal.add(close, Decimal.mult(range, mult_1_2))
    r1 = Decimal.add(close, Decimal.mult(range, mult_1_1))

    # Calculate support levels
    s1 = Decimal.sub(close, Decimal.mult(range, mult_1_1))
    s2 = Decimal.sub(close, Decimal.mult(range, mult_1_2))
    s3 = Decimal.sub(close, Decimal.mult(range, mult_1_3))
    s4 = Decimal.sub(close, Decimal.mult(range, mult_1_5))

    # Calculate pivot (average of OHLC)
    pivot = Decimal.div(
      Decimal.add(Decimal.add(high, low), Decimal.mult(close, Decimal.new(2))),
      Decimal.new(4)
    )

    %{
      pivot: pivot,
      r1: r1, r2: r2, r3: r3, r4: r4,
      s1: s1, s2: s2, s3: s3, s4: s4
    }
  end

  @doc """
  Calculates Woodie's pivot points.

  ## Parameters
    - candle: A single candle representing the period (typically daily)
      containing high, low, close, and open prices

  ## Returns
    - Map with calculated Woodie's pivot points
      %{
        pivot: value,
        r1: value, r2: value,
        s1: value, s2: value
      }
  """
  def woodie(%{high: high, low: low, close: _close, open: open}) do
    # Calculate pivot point (P) - Weighted more toward the open and close
    pivot = Decimal.div(
      Decimal.add(Decimal.add(high, low), Decimal.mult(open, Decimal.new(2))),
      Decimal.new(4)
    )

    # Calculate range
    range = Decimal.sub(high, low)

    # Calculate resistance levels
    r1 = Decimal.mult(Decimal.new(2), pivot) |> Decimal.sub(low)
    r2 = Decimal.add(pivot, range)

    # Calculate support levels
    s1 = Decimal.mult(Decimal.new(2), pivot) |> Decimal.sub(high)
    s2 = Decimal.sub(pivot, range)

    %{
      pivot: pivot,
      r1: r1, r2: r2,
      s1: s1, s2: s2
    }
  end
end
