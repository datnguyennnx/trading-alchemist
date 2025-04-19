defmodule Central.Backtest.Indicators.Trend.Donchian do
  @moduledoc """
  Implements the Donchian Channels indicator.

  Donchian Channels consist of an upper and lower band that mark the highest high
  and lowest low of a security over a specified period. The area between the upper
  and lower bands represents the Donchian Channel. A middle line is often included,
  which is the average of the upper and lower bands.
  """

  @doc """
  Calculates Donchian Channels.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to look back (typically 20)

  ## Returns
    - List of maps containing channel values aligned with input candles:
      %{
        upper: value,  # Highest high over period
        middle: value, # Average of upper and lower
        lower: value   # Lowest low over period
      }
  """
  def donchian(candles, period \\ 20) when is_list(candles) and is_integer(period) and period > 0 do
    # Get high and low values
    highs = Enum.map(candles, & &1.high)
    lows = Enum.map(candles, & &1.low)

    # Calculate channels for each period
    channels = calculate_channels(highs, lows, period)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(channels)
    List.duplicate(nil, padding_length) ++ channels
  end

  # Calculate channels for each window
  defp calculate_channels(highs, lows, period) do
    # Create sliding windows
    high_windows = Enum.chunk_every(highs, period, 1, :discard)
    low_windows = Enum.chunk_every(lows, period, 1, :discard)

    # Calculate channels for each window
    Enum.zip(high_windows, low_windows)
    |> Enum.map(fn {high_window, low_window} ->
      # Upper band is highest high
      upper = Enum.max_by(high_window, &Decimal.to_float/1)

      # Lower band is lowest low
      lower = Enum.min_by(low_window, &Decimal.to_float/1)

      # Middle band is average of upper and lower
      middle = Decimal.div(Decimal.add(upper, lower), Decimal.new(2))

      %{
        upper: upper,
        middle: middle,
        lower: lower
      }
    end)
  end

  @doc """
  Calculates the Donchian Breakout Signals.

  The breakout signals occur when price breaks above the upper band (buy signal)
  or below the lower band (sell signal).

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the channel calculation (typically 20)

  ## Returns
    - List of signals aligned with input candles:
      :buy, :sell, or nil (no signal)
  """
  def donchian_breakout(candles, period \\ 20) when is_list(candles) and is_integer(period) and period > 0 do
    # Calculate Donchian Channels
    channels = donchian(candles, period)

    # Pair channels with corresponding candles
    Enum.zip(channels, candles)
    |> Enum.map(fn
      {nil, _} -> nil  # No channel data for this period
      {channel, candle} ->
        cond do
          # Buy signal: close price breaks above upper band
          Decimal.compare(candle.close, channel.upper) == :gt -> :buy

          # Sell signal: close price breaks below lower band
          Decimal.compare(candle.close, channel.lower) == :lt -> :sell

          # No signal
          true -> nil
        end
    end)
  end
end
