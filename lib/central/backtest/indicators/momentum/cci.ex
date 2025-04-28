defmodule Central.Backtest.Indicators.Momentum.CCI do
  @moduledoc """
  Implements the Commodity Channel Index (CCI) indicator.

  CCI measures the current price level relative to an average price level over a given period.
  It is used to identify cyclical trends and extremes that could indicate overbought or oversold conditions.
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates the Commodity Channel Index (CCI).

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for calculation (typically 20)
    - constant: Scaling constant (typically 0.015)

  ## Returns
    - List of CCI values aligned with input candles (first period-1 values are nil)
  """
  def cci(candles, period \\ 20, constant \\ 0.015)
      when is_list(candles) and is_integer(period) and period > 0 and
             is_number(constant) and constant > 0 do
    # Calculate typical price for each candle
    typical_prices =
      Enum.map(candles, fn candle ->
        # TP = (High + Low + Close) / 3
        Decimal.div(
          Decimal.add(Decimal.add(candle.high, candle.low), candle.close),
          Decimal.new(3)
        )
      end)

    # Calculate simple moving average of typical prices
    sma_values = MovingAverage.sma(typical_prices, period)

    # Calculate Mean Deviation
    mean_deviations = calculate_mean_deviation(typical_prices, sma_values, period)

    # Calculate CCI values
    cci_values = calculate_cci_values(typical_prices, sma_values, mean_deviations, constant)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(cci_values)
    List.duplicate(nil, padding_length) ++ cci_values
  end

  # Calculate Mean Deviation for each period
  defp calculate_mean_deviation(typical_prices, sma_values, period) do
    # Create windows of typical prices
    typical_prices_windows = Enum.chunk_every(typical_prices, period, 1, :discard)

    # Calculate mean deviation for each window
    Enum.zip(typical_prices_windows, sma_values)
    |> Enum.map(fn {tp_window, sma} ->
      # Mean Deviation = Sum(|TP - SMA|) / period
      sum_of_deviations =
        Enum.reduce(tp_window, Decimal.new(0), fn tp, sum ->
          deviation = Decimal.sub(tp, sma) |> Decimal.abs()
          Decimal.add(sum, deviation)
        end)

      Decimal.div(sum_of_deviations, Decimal.new(period))
    end)
  end

  # Calculate CCI values
  defp calculate_cci_values(typical_prices, sma_values, mean_deviations, constant) do
    decimal_constant = Decimal.from_float(constant)

    # Calculate CCI for each data point where we have SMA and Mean Deviation
    Enum.zip([
      Enum.drop(typical_prices, length(typical_prices) - length(sma_values)),
      sma_values,
      mean_deviations
    ])
    |> Enum.map(fn {tp, sma, mean_dev} ->
      # Handle division by zero (mean deviation is zero)
      if Decimal.equal?(mean_dev, Decimal.new(0)) do
        # Default to 0 when mean deviation is 0
        Decimal.new(0)
      else
        # CCI = (TP - SMA) / (constant * MD)
        Decimal.div(
          Decimal.sub(tp, sma),
          Decimal.mult(decimal_constant, mean_dev)
        )
      end
    end)
  end
end
