defmodule Central.Backtest.Indicators.Trend.Macd do
  @moduledoc """
  Implementation of the Moving Average Convergence Divergence (MACD) indicator.

  MACD is a trend-following momentum indicator that shows the relationship
  between two moving averages of a security's price.
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates the Moving Average Convergence Divergence (MACD) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - fast_period: Period for the fast EMA (typically 12)
    - slow_period: Period for the slow EMA (typically 26)
    - signal_period: Period for the signal line EMA (typically 9)
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of maps containing MACD values aligned with the input candles:
      %{macd: value, signal: value, histogram: value}
      (first slow_period + signal_period - 2 values are nil)
  """
  def macd(
        candles,
        fast_period \\ 12,
        slow_period \\ 26,
        signal_period \\ 9,
        price_key \\ :close
      )
      when is_list(candles) and is_integer(fast_period) and is_integer(slow_period) and
             is_integer(signal_period) do
    # Calculate fast and slow EMAs
    fast_ema = MovingAverage.ema(candles, fast_period, price_key)
    slow_ema = MovingAverage.ema(candles, slow_period, price_key)

    # Calculate MACD line: fast_ema - slow_ema
    macd_line =
      Enum.zip(fast_ema, slow_ema)
      |> Enum.map(fn
        {nil, _} -> nil
        {_, nil} -> nil
        {fast, slow} -> Decimal.sub(fast, slow)
      end)

    # Get the valid MACD values (non-nil)
    # Index where MACD values start
    valid_macd_start = slow_period - 1
    valid_macd = Enum.drop(macd_line, valid_macd_start)

    # Calculate signal line: EMA of MACD line
    valid_signal = MovingAverage.calculate_ema_from_values(valid_macd, signal_period)

    # Align signal with original MACD by adding nils at beginning
    signal_line = List.duplicate(nil, valid_macd_start + signal_period - 1) ++ valid_signal

    # Calculate histogram: MACD line - signal line
    Enum.zip(macd_line, signal_line)
    |> Enum.map(fn
      {nil, _} ->
        nil

      {_, nil} ->
        nil

      {macd, signal} ->
        histogram = Decimal.sub(macd, signal)
        %{macd: macd, signal: signal, histogram: histogram}
    end)
  end
end
