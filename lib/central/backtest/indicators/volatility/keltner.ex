defmodule Central.Backtest.Indicators.Volatility.Keltner do
  @moduledoc """
  Implements the Keltner Channels indicator.

  Keltner Channels are volatility-based envelopes set above and below an exponential moving average.
  This indicator is similar to Bollinger Bands, which use the standard deviation to set the bands.
  Keltner Channels use the Average True Range (ATR) to set channel distance.
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage
  alias Central.Backtest.Indicators.Volatility.Atr

  @doc """
  Calculates Keltner Channels.

  ## Parameters
    - candles: List of market data candles
    - ema_period: Period for the EMA calculation (typically 20)
    - atr_period: Period for the ATR calculation (typically 10)
    - multiplier: Multiplier for the ATR to set channel width (typically 2)
    - price_key: Key to use for price extraction (:close, :open, etc.)

  ## Returns
    - List of maps containing Keltner Channel values aligned with input candles:
      %{
        middle: value, # EMA
        upper: value,  # EMA + (ATR * multiplier)
        lower: value   # EMA - (ATR * multiplier)
      }
  """
  def keltner(candles, ema_period \\ 20, atr_period \\ 10, multiplier \\ 2, price_key \\ :close)
    when is_list(candles) and is_integer(ema_period) and ema_period > 0
    and is_integer(atr_period) and atr_period > 0
    and is_number(multiplier) and multiplier > 0 do

    # Calculate EMA (middle channel)
    middle_line = MovingAverage.ema(candles, ema_period, price_key)

    # Calculate ATR
    atr_values = Atr.atr(candles, atr_period)

    # Calculate upper and lower bands
    decimal_multiplier = Decimal.new(multiplier)

    # Zip EMA and ATR values
    Enum.zip(middle_line, atr_values)
    |> Enum.map(fn
      {nil, _} -> nil
      {_, nil} -> nil
      {ema, atr} ->
        # Upper = EMA + (ATR * multiplier)
        upper = Decimal.add(ema, Decimal.mult(atr, decimal_multiplier))

        # Lower = EMA - (ATR * multiplier)
        lower = Decimal.sub(ema, Decimal.mult(atr, decimal_multiplier))

        %{
          middle: ema,
          upper: upper,
          lower: lower
        }
    end)
  end
end
