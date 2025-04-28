defmodule Central.Backtest.Indicators.Trend.ParabolicSar do
  @moduledoc """
  Implements the Parabolic SAR (Stop and Reverse) indicator.

  The Parabolic SAR is a trend-following indicator that helps identify potential
  reversal points in price movement. It appears as a series of dots placed above
  or below the price bars, indicating potential stop and reverse points.
  """

  @doc """
  Calculates the Parabolic SAR values.

  ## Parameters
    - candles: List of market data candles
    - acceleration_factor_start: Starting acceleration factor (typically 0.02)
    - acceleration_factor_max: Maximum acceleration factor (typically 0.2)
    - acceleration_factor_step: Step for increasing acceleration factor (typically 0.02)

  ## Returns
    - List of SAR values aligned with input candles (first value is nil)
  """
  def parabolic_sar(
        candles,
        acceleration_factor_start \\ 0.02,
        acceleration_factor_max \\ 0.2,
        acceleration_factor_step \\ 0.02
      )
      when is_list(candles) and length(candles) > 1 and
             is_number(acceleration_factor_start) and acceleration_factor_start > 0 and
             is_number(acceleration_factor_max) and
             acceleration_factor_max > acceleration_factor_start and
             is_number(acceleration_factor_step) and acceleration_factor_step > 0 do
    # Need at least 2 candles to start
    if length(candles) < 2 do
      List.duplicate(nil, length(candles))
    else
      # Determine initial trend
      # If second close is higher than first, we're in an uptrend
      [first_candle, second_candle | _] = candles
      initial_uptrend = Decimal.compare(second_candle.close, first_candle.close) == :gt

      # Set initial values
      initial_ep =
        if initial_uptrend do
          # In uptrend, start with first high
          first_candle.high
        else
          # In downtrend, start with first low
          first_candle.low
        end

      initial_sar =
        if initial_uptrend do
          # In uptrend, SAR starts at the first low
          first_candle.low
        else
          # In downtrend, SAR starts at the first high
          first_candle.high
        end

      # Calculate SAR values for all candles
      {sar_values, _, _, _, _} =
        Enum.reduce(
          Enum.drop(candles, 1),
          {[initial_sar], initial_uptrend, initial_ep, initial_sar,
           Decimal.from_float(acceleration_factor_start)},
          fn candle, {results, uptrend, ep, prior_sar, af} ->
            # Calculate new SAR value
            new_sar =
              calculate_new_sar(
                candle,
                uptrend,
                ep,
                prior_sar,
                af,
                acceleration_factor_max,
                acceleration_factor_step
              )

            # Add to results and prepare for next iteration
            {[new_sar | results], new_sar.uptrend, new_sar.ep, new_sar.value, new_sar.af}
          end
        )

      # Format and align results
      formatted_sars =
        Enum.reverse(sar_values)
        |> Enum.map(fn
          %{value: value} -> value
          # For the initial SAR value which is just a Decimal
          value -> value
        end)

      # Add nil for the very first value where SAR isn't defined
      [nil | formatted_sars]
    end
  end

  # Calculate a new SAR value based on current state
  defp calculate_new_sar(candle, uptrend, ep, prior_sar, af, af_max, af_step) do
    decimal_af_step = Decimal.from_float(af_step)
    decimal_af_max = Decimal.from_float(af_max)

    # Calculate new SAR value for current period
    sar_value =
      Decimal.add(
        prior_sar,
        Decimal.mult(af, Decimal.sub(ep, prior_sar))
      )

    # Check if trend has reversed
    reversed =
      if uptrend do
        # In uptrend, reverse if price drops below SAR
        Decimal.compare(candle.low, sar_value) == :lt
      else
        # In downtrend, reverse if price rises above SAR
        Decimal.compare(candle.high, sar_value) == :gt
      end

    if reversed do
      # Trend has reversed, flip everything
      new_uptrend = not uptrend

      new_ep =
        if new_uptrend do
          # New uptrend, EP is high
          candle.high
        else
          # New downtrend, EP is low
          candle.low
        end

      # Reset acceleration factor
      new_af = Decimal.from_float(af_step)

      # SAR becomes the previous extreme point
      new_sar_value = ep

      %{value: new_sar_value, uptrend: new_uptrend, ep: new_ep, af: new_af}
    else
      # No reversal, continue trend
      # Check for new extreme point
      {new_ep, new_af} =
        if uptrend do
          # In uptrend, EP is highest high
          if Decimal.compare(candle.high, ep) == :gt do
            # New high found, increase AF
            new_af =
              Decimal.min(
                Decimal.add(af, decimal_af_step),
                decimal_af_max
              )

            {candle.high, new_af}
          else
            # No new high, AF stays the same
            {ep, af}
          end
        else
          # In downtrend, EP is lowest low
          if Decimal.compare(candle.low, ep) == :lt do
            # New low found, increase AF
            new_af =
              Decimal.min(
                Decimal.add(af, decimal_af_step),
                decimal_af_max
              )

            {candle.low, new_af}
          else
            # No new low, AF stays the same
            {ep, af}
          end
        end

      # Ensure SAR doesn't penetrate recent price action
      bounded_sar = bound_sar_value(sar_value, [candle], uptrend)

      %{value: bounded_sar, uptrend: uptrend, ep: new_ep, af: new_af}
    end
  end

  # Ensure SAR value doesn't penetrate recent price action
  defp bound_sar_value(sar, recent_candles, uptrend) do
    if uptrend do
      # In uptrend, SAR must be below recent lows
      min_low = Enum.map(recent_candles, & &1.low) |> Enum.min_by(&Decimal.to_float/1)

      if Decimal.compare(sar, min_low) == :gt do
        # SAR is above recent low, bound it to the low
        min_low
      else
        sar
      end
    else
      # In downtrend, SAR must be above recent highs
      max_high = Enum.map(recent_candles, & &1.high) |> Enum.max_by(&Decimal.to_float/1)

      if Decimal.compare(sar, max_high) == :lt do
        # SAR is below recent high, bound it to the high
        max_high
      else
        sar
      end
    end
  end
end
