defmodule Central.Backtest.Indicators.Volatility.BollingerBands do
  @moduledoc """
  Implements Bollinger Bands calculations.
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage
  alias Central.Backtest.Indicators.Calculations.{ListOperations}

  @doc """
  Calculates Bollinger Bands for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Period for the SMA (typically 20)
    - deviations: Number of standard deviations (typically 2)
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of maps containing Bollinger Bands values aligned with the input candles:
      %{middle: value, upper: value, lower: value}
      (first period-1 values are nil)
  """
  def bollinger_bands(candles, period \\ 20, deviations \\ 2, price_key \\ :close)
      when is_list(candles) and is_integer(period) and period > 0 do
    prices = ListOperations.extract_key(candles, price_key)

    # Middle band is SMA
    sma_values = MovingAverage.sma(candles, period, price_key)

    # Calculate standard deviation at each point
    std_devs = calculate_rolling_std_dev(prices, period, sma_values)

    # Calculate upper and lower bands
    Enum.zip([sma_values, std_devs])
    |> Enum.map(fn
      {nil, _} ->
        nil

      {sma, std_dev} ->
        upper = Decimal.add(sma, Decimal.mult(std_dev, Decimal.new(deviations)))
        lower = Decimal.sub(sma, Decimal.mult(std_dev, Decimal.new(deviations)))
        %{middle: sma, upper: upper, lower: lower}
    end)
  end

  defp calculate_rolling_std_dev(prices, period, sma_values) do
    prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.zip(Enum.drop(sma_values, period - 1))
    |> Enum.map(fn {window, sma} ->
      if is_nil(sma) do
        nil
      else
        # Calculate variance: sum of squared differences from mean, divided by period
        variance =
          Enum.reduce(window, Decimal.new(0), fn price, acc ->
            diff = Decimal.sub(price, sma)
            squared_diff = Decimal.mult(diff, diff)
            Decimal.add(acc, squared_diff)
          end)
          |> Decimal.div(Decimal.new(period))

        # Standard deviation is square root of variance
        Decimal.sqrt(variance)
      end
    end)
    |> then(fn std_devs ->
      # Add nil values at the beginning to align with input
      List.duplicate(nil, period - 1) ++ std_devs
    end)
  end
end
