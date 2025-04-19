defmodule Central.Backtest.Indicators.Trend.Gmma do
  @moduledoc """
  Implementation of the Guppy Multiple Moving Average (GMMA).

  The GMMA uses multiple exponential moving averages to identify market trends.
  It consists of two sets of moving averages:
  1. Short-term EMAs (typically 3, 5, 8, 10, 12, 15 periods)
  2. Long-term EMAs (typically 30, 35, 40, 45, 50, 60 periods)

  The relationship between these moving averages helps traders identify trend strength,
  potential reversals, and trading opportunities.
  """

  alias Central.Backtest.Indicators.IndicatorUtils

  @doc """
  Calculates the Guppy Multiple Moving Average (GMMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - options: Optional parameters
      - short_periods: List of periods for short-term EMAs (default: [3, 5, 8, 10, 12, 15])
      - long_periods: List of periods for long-term EMAs (default: [30, 35, 40, 45, 50, 60])
      - price_key: Key to use for price (default: :close)

  ## Returns
    - Map containing:
      - :short_emas - List of short-term EMA lists
      - :long_emas - List of long-term EMA lists
      - :dates - List of dates (if present in candles)
  """
  @spec calculate(list(), keyword()) :: map()
  def calculate(candles, options \\ []) do
    short_periods = Keyword.get(options, :short_periods, [3, 5, 8, 10, 12, 15])
    long_periods = Keyword.get(options, :long_periods, [30, 35, 40, 45, 50, 60])
    price_key = Keyword.get(options, :price_key, :close)

    prices = IndicatorUtils.extract_price(candles, price_key)

    # Calculate all short-term EMAs
    short_emas = Enum.map(short_periods, fn period ->
      IndicatorUtils.ema(prices, period)
    end)

    # Calculate all long-term EMAs
    long_emas = Enum.map(long_periods, fn period ->
      IndicatorUtils.ema(prices, period)
    end)

    # Extract dates if they exist
    dates = extract_dates(candles)

    # Return structured result
    %{
      short_emas: short_emas,
      long_emas: long_emas,
      dates: dates
    }
  end

  defp extract_dates(candles) do
    IndicatorUtils.extract_price(candles, :timestamp)
  end

  @doc """
  Analyzes GMMA data to determine trend direction, strength, and potential signals.

  ## Parameters
    - gmma_result: Result map from calculate/2 function
    - options: Additional options for analysis

  ## Returns
    - {:ok, analysis} where analysis is a list of maps with trend analysis data
  """
  @spec analyze(map(), keyword()) :: {:ok, list()}
  def analyze(gmma_result, _options \\ []) do
    %{short_emas: short_emas, long_emas: long_emas} = gmma_result

    # Determine the number of data points
    n_points = length(List.first(short_emas))

    # Prepare lists for analysis
    analysis = for i <- 0..(n_points - 1) do
      # Extract all EMAs at this index
      short_values = Enum.map(short_emas, &Enum.at(&1, i))
      long_values = Enum.map(long_emas, &Enum.at(&1, i))

      all_values = short_values ++ long_values

      # Skip analysis if we don't have enough data yet
      if Enum.any?(all_values, &is_nil/1) do
        %{
          trend: :insufficient_data,
          strength: :insufficient_data,
          signal: :insufficient_data,
          compression: :insufficient_data
        }
      else
        # Analyze the GMMA configuration
        {trend, strength} = analyze_trend(short_values, long_values)
        compression = measure_compression(short_values, long_values)
        signal = determine_signal(short_values, long_values, compression)

        %{
          trend: trend,
          strength: strength,
          signal: signal,
          compression: compression,
          short_values: short_values,
          long_values: long_values
        }
      end
    end

    {:ok, analysis}
  end

  defp analyze_trend(short_values, long_values) do
    # Get min and max values from both groups
    min_short = Enum.min_by(short_values, fn a -> Decimal.to_float(a) end)
    max_short = Enum.max_by(short_values, fn a -> Decimal.to_float(a) end)
    min_long = Enum.min_by(long_values, fn a -> Decimal.to_float(a) end)
    max_long = Enum.max_by(long_values, fn a -> Decimal.to_float(a) end)

    # Analyze the relationship between short and long groups
    cond do
      # Bullish: All short EMAs above long EMAs
      Decimal.gt?(min_short, max_long) -> {:bullish, :strong}

      # Bearish: All short EMAs below long EMAs
      Decimal.gt?(min_long, max_short) -> {:bearish, :strong}

      # Moderately bullish: Most short EMAs above long EMAs
      Decimal.gt?(Enum.at(short_values, 0), Enum.at(long_values, 5)) -> {:bullish, :moderate}

      # Moderately bearish: Most short EMAs below long EMAs
      Decimal.gt?(Enum.at(long_values, 0), Enum.at(short_values, 5)) -> {:bearish, :moderate}

      # Mixed: No clear pattern
      true -> {:sideways, :weak}
    end
  end

  defp measure_compression(short_values, long_values) do
    # Calculate the range of each group
    short_range = measure_group_range(short_values)
    long_range = measure_group_range(long_values)

    # Determine compression level based on range
    cond do
      Decimal.lt?(short_range, Decimal.mult(Decimal.new("0.1"), Enum.at(short_values, 0))) and
      Decimal.lt?(long_range, Decimal.mult(Decimal.new("0.1"), Enum.at(long_values, 0))) ->
        :high_compression

      Decimal.lt?(short_range, Decimal.mult(Decimal.new("0.2"), Enum.at(short_values, 0))) and
      Decimal.lt?(long_range, Decimal.mult(Decimal.new("0.2"), Enum.at(long_values, 0))) ->
        :moderate_compression

      true ->
        :low_compression
    end
  end

  defp measure_group_range(values) do
    min_val = Enum.min_by(values, fn a -> Decimal.to_float(a) end)
    max_val = Enum.max_by(values, fn a -> Decimal.to_float(a) end)
    Decimal.sub(max_val, min_val)
  end

  defp determine_signal(short_values, long_values, compression) do
    # Simplified signal determination
    {trend, strength} = analyze_trend(short_values, long_values)

    case {trend, strength, compression} do
      {:bullish, :strong, :high_compression} -> :strong_buy
      {:bearish, :strong, :high_compression} -> :strong_sell
      {:bullish, :strong, _} -> :buy
      {:bearish, :strong, _} -> :sell
      {:bullish, :moderate, _} -> :weak_buy
      {:bearish, :moderate, _} -> :weak_sell
      {_, _, :high_compression} -> :potential_breakout
      _ -> :hold
    end
  end

  @doc """
  Convenience function to calculate GMMA with custom periods.

  ## Parameters
    - candles: List of market data candles
    - short_periods: List of periods for short-term EMAs
    - long_periods: List of periods for long-term EMAs
    - price_key: Key to use for price

  ## Returns
    - {:ok, result} where result is a map with :short_emas and :long_emas
  """
  @spec gmma(list(), list(), list(), atom()) :: {:ok, map()}
  def gmma(candles, short_periods \\ [3, 5, 8, 10, 12, 15], long_periods \\ [30, 35, 40, 45, 50, 60], price_key \\ :close) do
    result = calculate(candles, [
      short_periods: short_periods,
      long_periods: long_periods,
      price_key: price_key
    ])

    {:ok, result}
  end
end
