defmodule Central.Backtest.Indicators.Volatility.StdDev do
  @moduledoc """
  Implements Standard Deviation calculations for volatility analysis.

  Standard Deviation measures the dispersion of a dataset relative to its mean.
  In trading, it's a common measure of market volatility and is a key component
  of other indicators like Bollinger Bands.
  """

  alias Central.Backtest.Indicators.Calculations.ListOperations
  alias Central.Backtest.Indicators.Calculations.Math
  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates the Standard Deviation of price data.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for calculation (typically 20)
    - price_key: Key to use for price data (:close, :open, etc.)
    - type: Type of calculation (:population or :sample)

  ## Returns
    - List of Standard Deviation values aligned with input candles (first period-1 values are nil)
  """
  def standard_deviation(candles, period \\ 20, price_key \\ :close, type \\ :population)
      when is_list(candles) and is_integer(period) and period > 0 and
             type in [:population, :sample] do
    # Extract price data
    prices = ListOperations.extract_key(candles, price_key)

    # Calculate rolling standard deviation
    std_values = rolling_std_dev(prices, period, type)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(std_values)
    List.duplicate(nil, padding_length) ++ std_values
  end

  @doc """
  Calculates the Standard Deviation of a single price window.

  ## Parameters
    - prices: List of price values
    - type: Type of calculation (:population or :sample)

  ## Returns
    - Standard Deviation as a Decimal
  """
  def calculate_std_dev(prices, type \\ :population)
      when is_list(prices) and length(prices) > 0 do
    # Calculate mean
    mean = Math.average(prices)

    # Calculate sum of squared differences
    sum_of_squares =
      Enum.reduce(prices, Decimal.new(0), fn price, acc ->
        diff = Decimal.sub(price, mean)
        squared_diff = Decimal.mult(diff, diff)
        Decimal.add(acc, squared_diff)
      end)

    # Adjust divisor based on type of standard deviation
    divisor =
      case type do
        :population -> length(prices)
        # Avoid division by zero
        :sample -> max(1, length(prices) - 1)
      end

    # Calculate variance
    variance = Decimal.div(sum_of_squares, Decimal.new(divisor))

    # Standard deviation is the square root of variance
    Math.decimal_sqrt(variance)
  end

  @doc """
  Calculates the Coefficient of Variation, which is the std dev relative to the mean.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for calculation (typically 20)
    - price_key: Key to use for price data (:close, :open, etc.)

  ## Returns
    - List of CV values aligned with input candles (first period-1 values are nil)
  """
  def coefficient_of_variation(candles, period \\ 20, price_key \\ :close)
      when is_list(candles) and is_integer(period) and period > 0 do
    # Extract price data
    prices = ListOperations.extract_key(candles, price_key)

    # Calculate SMA values
    sma_values = MovingAverage.sma(prices, period)

    # Calculate standard deviation values
    std_values = rolling_std_dev(prices, period)

    # Calculate Coefficient of Variation: CV = StdDev / Mean
    cv_values =
      Enum.zip(std_values, sma_values)
      |> Enum.map(fn
        {nil, _} ->
          nil

        {_, nil} ->
          nil

        {std, mean} ->
          # Avoid division by zero
          if Decimal.equal?(mean, Decimal.new(0)) do
            Decimal.new(0)
          else
            Decimal.div(std, mean)
          end
      end)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(cv_values)
    List.duplicate(nil, padding_length) ++ cv_values
  end

  # Calculate rolling standard deviation for each window of prices
  defp rolling_std_dev(prices, period, type \\ :population)

  defp rolling_std_dev(prices, period, type) when length(prices) >= period do
    # Create sliding windows
    price_windows = Enum.chunk_every(prices, period, 1, :discard)

    # Calculate standard deviation for each window
    Enum.map(price_windows, fn window ->
      calculate_std_dev(window, type)
    end)
  end

  defp rolling_std_dev(_prices, _period, _type), do: []

  @doc """
  Calculates a volatility ratio by comparing short-term to long-term standard deviation.

  ## Parameters
    - candles: List of market data candles
    - short_period: Number of periods for short-term calculation (typically 5)
    - long_period: Number of periods for long-term calculation (typically 20)
    - price_key: Key to use for price data (:close, :open, etc.)

  ## Returns
    - List of volatility ratio values aligned with input candles
  """
  def volatility_ratio(candles, short_period \\ 5, long_period \\ 20, price_key \\ :close)
      when is_list(candles) and is_integer(short_period) and short_period > 0 and
             is_integer(long_period) and long_period > 0 and short_period < long_period do
    # Calculate short-term standard deviation
    short_std = standard_deviation(candles, short_period, price_key)

    # Calculate long-term standard deviation
    long_std = standard_deviation(candles, long_period, price_key)

    # Calculate ratio: ShortStdDev / LongStdDev
    Enum.zip(short_std, long_std)
    |> Enum.map(fn
      {nil, _} ->
        nil

      {_, nil} ->
        nil

      {short, long} ->
        # Avoid division by zero
        if Decimal.equal?(long, Decimal.new(0)) do
          # Default to 1 (neutral) when long-term vol is zero
          Decimal.new(1)
        else
          Decimal.div(short, long)
        end
    end)
  end
end
