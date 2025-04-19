defmodule Central.Backtest.Indicators.Trend.DonchianChannel do
  @moduledoc """
  Implementation of the Donchian Channel.

  This module delegates to the Donchian module for compatibility with
  the public API in the indicators.ex facade module.
  """

  alias Central.Backtest.Indicators.Trend.Donchian

  @doc """
  Calculates Donchian Channel for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to look back (default: 20)

  ## Returns
    - Same return values as Donchian.donchian/2
  """
  def donchian_channel(candles, period \\ 20) do
    Donchian.donchian(candles, period)
  end
end
