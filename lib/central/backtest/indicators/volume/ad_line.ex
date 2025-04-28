defmodule Central.Backtest.Indicators.Volume.AdLine do
  @moduledoc """
  Implements the Accumulation/Distribution Line indicator.

  The A/D Line measures the cumulative flow of money into and out of a security.
  It aims to identify divergences between price and volume that may signal future price movements.
  """

  @doc """
  Calculates the Accumulation/Distribution Line.

  ## Parameters
    - candles: List of market data candles

  ## Returns
    - List of A/D Line values aligned with input candles
  """
  def ad_line(candles) when is_list(candles) and length(candles) > 0 do
    # Calculate Money Flow Multiplier and Money Flow Volume for each candle
    mf_volumes =
      Enum.map(candles, fn candle ->
        # Money Flow Multiplier = ((Close - Low) - (High - Close)) / (High - Low)
        high_low_diff = Decimal.sub(candle.high, candle.low)

        mf_multiplier =
          if Decimal.equal?(high_low_diff, Decimal.new(0)) do
            # If high equals low, multiplier is 0
            Decimal.new(0)
          else
            close_low_diff = Decimal.sub(candle.close, candle.low)
            high_close_diff = Decimal.sub(candle.high, candle.close)
            numerator = Decimal.sub(close_low_diff, high_close_diff)

            Decimal.div(numerator, high_low_diff)
          end

        # Money Flow Volume = Money Flow Multiplier * Volume
        Decimal.mult(mf_multiplier, candle.volume)
      end)

    # Calculate cumulative A/D Line
    {ad_line_values, _} =
      Enum.map_reduce(mf_volumes, Decimal.new(0), fn mfv, prev_ad ->
        new_ad = Decimal.add(prev_ad, mfv)
        {new_ad, new_ad}
      end)

    ad_line_values
  end

  @doc """
  Calculates the Chaikin A/D Oscillator, which is a momentum indicator derived from the A/D Line.

  ## Parameters
    - candles: List of market data candles
    - fast_period: Period for the fast EMA (typically 3)
    - slow_period: Period for the slow EMA (typically 10)

  ## Returns
    - List of Chaikin Oscillator values aligned with input candles
  """
  def chaikin_oscillator(candles, fast_period \\ 3, slow_period \\ 10)
      when is_list(candles) and is_integer(fast_period) and fast_period > 0 and
             is_integer(slow_period) and slow_period > 0 do
    # Calculate A/D Line
    ad_values = ad_line(candles)

    # Calculate fast EMA of A/D Line
    fast_ema = calculate_ema(ad_values, fast_period)

    # Calculate slow EMA of A/D Line
    slow_ema = calculate_ema(ad_values, slow_period)

    # Calculate Chaikin Oscillator (Fast EMA - Slow EMA)
    oscillator_values =
      Enum.zip(fast_ema, slow_ema)
      |> Enum.map(fn
        {nil, _} -> nil
        {_, nil} -> nil
        {fast, slow} -> Decimal.sub(fast, slow)
      end)

    # Align with input data
    max_len = length(candles)
    padding_length = max_len - length(oscillator_values)
    List.duplicate(nil, padding_length) ++ oscillator_values
  end

  # Calculate EMA for A/D Line values
  defp calculate_ema(values, period) when length(values) >= period do
    # Calculate multiplier: (2 / (period + 1))
    multiplier =
      Decimal.div(
        Decimal.new(2),
        Decimal.add(Decimal.new(period), Decimal.new(1))
      )

    # Calculate first SMA
    first_period_values = Enum.take(values, period)
    first_sma = (Enum.sum(first_period_values) / period) |> Decimal.from_float()

    # Calculate subsequent EMAs
    rest_values = Enum.drop(values, period)

    {result, _} =
      Enum.map_reduce(rest_values, first_sma, fn value, prev_ema ->
        # EMA = (Current value * multiplier) + (Previous EMA * (1 - multiplier))
        ema_part1 = Decimal.mult(value, multiplier)

        ema_part2 =
          Decimal.mult(
            prev_ema,
            Decimal.sub(Decimal.new(1), multiplier)
          )

        new_ema = Decimal.add(ema_part1, ema_part2)
        {new_ema, new_ema}
      end)

    # Return all EMAs including the first SMA
    [first_sma | result]
  end

  defp calculate_ema(values, _period), do: List.duplicate(nil, length(values))
end
