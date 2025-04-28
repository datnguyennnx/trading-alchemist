defmodule Central.Backtest.Indicators.Volatility.StandardDeviation do
  @moduledoc """
  Implementation of the Standard Deviation indicator.

  Standard Deviation measures the dispersion or variability of a data set from its average value.
  In trading, it's commonly used to measure market volatility and as a component of other indicators
  like Bollinger Bands.

  A high standard deviation indicates high volatility, while a low standard deviation suggests
  lower volatility and more stable price action.
  """

  @doc """
  Calculates the Standard Deviation for a list of candles.

  ## Parameters
    - candles: List of candle maps with OHLCV data
    - period: Number of periods for calculation (default: 20)
    - price_key: The price to use for calculations (default: :close)

  ## Returns
    - List of standard deviation values, one for each candle (first period-1 values will be nil)
  """
  def standard_deviation(candles, period \\ 20, price_key \\ :close) do
    prices = Enum.map(candles, &Map.get(&1, price_key))

    0..(length(prices) - 1)
    |> Enum.map(fn i ->
      if i < period - 1 do
        nil
      else
        # Get the window of prices for this period
        window = Enum.slice(prices, (i - period + 1)..i)

        # Calculate mean
        mean = Enum.sum(window) / period

        # Calculate variance
        variance =
          Enum.reduce(window, 0, fn price, acc ->
            acc + :math.pow(price - mean, 2)
          end) / period

        # Calculate standard deviation
        :math.sqrt(variance)
      end
    end)
  end

  @doc """
  Calculates standard deviation and returns a structured result.

  ## Parameters
    - candles: List of candle maps with OHLCV data
    - period: Number of periods for calculation (default: 20)
    - price_key: The price to use for calculations (default: :close)

  ## Returns
    - List of maps, each containing:
      - :timestamp - Timestamp from the candle
      - :price - Price used in the calculation
      - :std_dev - The standard deviation value
      - :volatility - Categorized volatility level (:low, :medium, :high)
  """
  def calculate(candles, period \\ 20, price_key \\ :close) do
    std_dev_values = standard_deviation(candles, period, price_key)

    # Calculate average std dev for volatility classification
    valid_std_devs = Enum.filter(std_dev_values, &(not is_nil(&1)))

    avg_std_dev =
      if length(valid_std_devs) > 0,
        do: Enum.sum(valid_std_devs) / length(valid_std_devs),
        else: 0

    Enum.zip(candles, std_dev_values)
    |> Enum.map(fn {candle, std_dev} ->
      price = Map.get(candle, price_key)

      # Determine volatility level
      volatility =
        cond do
          is_nil(std_dev) -> :unknown
          std_dev > avg_std_dev * 1.5 -> :high
          std_dev < avg_std_dev * 0.5 -> :low
          true -> :medium
        end

      # Calculate percent volatility (std dev as percentage of price)
      percent_volatility =
        if not is_nil(std_dev) and price > 0, do: std_dev / price * 100, else: nil

      %{
        timestamp: candle.timestamp,
        price: price,
        std_dev: std_dev,
        percent_volatility: percent_volatility,
        volatility: volatility
      }
    end)
  end

  @doc """
  Calculates normalized standard deviation to compare across different price ranges.

  ## Parameters
    - candles: List of candle maps with OHLCV data
    - period: Number of periods for calculation (default: 20)
    - price_key: The price to use for calculations (default: :close)

  ## Returns
    - List of normalized standard deviation values (as percentage of price)
  """
  def normalized_standard_deviation(candles, period \\ 20, price_key \\ :close) do
    std_dev_values = standard_deviation(candles, period, price_key)

    Enum.zip(candles, std_dev_values)
    |> Enum.map(fn {candle, std_dev} ->
      price = Map.get(candle, price_key)

      if is_nil(std_dev) or price == 0 do
        nil
      else
        # Express standard deviation as a percentage of price
        std_dev / price * 100
      end
    end)
  end

  @doc """
  Analyzes volatility trends based on standard deviation values.

  ## Parameters
    - std_dev_data: List of standard deviation result maps from calculate/3
    - trend_periods: Number of periods to analyze for trending volatility (default: 5)

  ## Returns
    - List of maps with enhanced volatility analysis
  """
  def analyze_volatility(std_dev_data, trend_periods \\ 5) do
    std_dev_data
    |> Enum.with_index()
    |> Enum.map(fn {point, index} ->
      # Need at least trend_periods points for trend analysis
      volatility_trend =
        if index >= trend_periods do
          previous_points = Enum.slice(std_dev_data, (index - trend_periods)..(index - 1))
          valid_points = Enum.filter(previous_points, &(not is_nil(&1.std_dev)))

          if length(valid_points) >= 3 and not is_nil(point.std_dev) do
            # Get std_dev values for trend analysis
            previous_std_devs = Enum.map(valid_points, & &1.std_dev)

            # Calculate average change to determine trend
            pairs = Enum.chunk_every(previous_std_devs, 2, 1, :discard)
            changes = Enum.map(pairs, fn [a, b] -> b - a end)

            avg_change = if length(changes) > 0, do: Enum.sum(changes) / length(changes), else: 0

            cond do
              avg_change > 0 and point.std_dev > List.last(previous_std_devs) ->
                :increasing

              avg_change < 0 and point.std_dev < List.last(previous_std_devs) ->
                :decreasing

              abs(avg_change) < 0.0001 ->
                :stable

              true ->
                :mixed
            end
          else
            :insufficient_data
          end
        else
          :insufficient_data
        end

      # Interpret trading conditions based on volatility
      trading_condition =
        cond do
          is_nil(point.volatility) or point.volatility == :unknown ->
            :unknown

          point.volatility == :high and volatility_trend == :increasing ->
            :extreme_volatility

          point.volatility == :high ->
            :high_volatility

          point.volatility == :low and volatility_trend == :decreasing ->
            :very_low_volatility

          point.volatility == :low ->
            :low_volatility

          volatility_trend == :increasing ->
            :increasing_volatility

          volatility_trend == :decreasing ->
            :decreasing_volatility

          true ->
            :normal_volatility
        end

      # Suggest trading strategies based on volatility conditions
      strategy =
        case trading_condition do
          :extreme_volatility -> :reduce_position_size
          :high_volatility -> :widen_stops
          :very_low_volatility -> :breakout_watch
          :low_volatility -> :tighten_stops
          :increasing_volatility -> :prepare_for_movement
          :decreasing_volatility -> :normal_trading
          :normal_volatility -> :normal_trading
          _ -> :insufficient_data
        end

      Map.merge(point, %{
        volatility_trend: volatility_trend,
        trading_condition: trading_condition,
        suggested_strategy: strategy
      })
    end)
  end
end
