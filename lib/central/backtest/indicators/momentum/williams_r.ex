defmodule Central.Backtest.Indicators.Momentum.WilliamsR do
  @moduledoc """
  Implements the Williams %R indicator.

  Williams %R is a momentum indicator that measures overbought and oversold levels.
  It shows the relationship of the close relative to the high-low range over a set time period.
  The indicator oscillates between 0 and -100, with readings from 0 to -20 considered overbought,
  and readings from -80 to -100 considered oversold.
  """

  @doc """
  Calculates Williams %R.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for calculation (typically 14)

  ## Returns
    - List of Williams %R values aligned with input candles (first period-1 values are nil)
  """
  def williams_r(candles, period \\ 14)
      when is_list(candles) and is_integer(period) and period > 0 do
    # Group data into sliding windows
    candle_windows = Enum.chunk_every(candles, period, 1, :discard)

    # Calculate Williams %R for each window
    williams_values =
      Enum.map(candle_windows, fn window ->
        # Get highest high and lowest low in the period
        highest_high = Enum.map(window, & &1.high) |> Enum.max_by(&Decimal.to_float/1)
        lowest_low = Enum.map(window, & &1.low) |> Enum.min_by(&Decimal.to_float/1)

        # Get current close (last close in the window)
        current_close = List.last(window).close

        # Calculate high-low range
        high_low_range = Decimal.sub(highest_high, lowest_low)

        # Handle case where high equals low
        if Decimal.equal?(high_low_range, Decimal.new(0)) do
          # Default to middle of range when there's no range
          Decimal.new(-50)
        else
          # Williams %R = ((Highest High - Close) / (Highest High - Lowest Low)) * -100
          Decimal.div(
            Decimal.sub(highest_high, current_close),
            high_low_range
          )
          |> Decimal.mult(Decimal.new(-100))
        end
      end)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(williams_values)
    List.duplicate(nil, padding_length) ++ williams_values
  end
end
