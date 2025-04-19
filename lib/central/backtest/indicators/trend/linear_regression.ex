defmodule Central.Backtest.Indicators.Trend.LinearRegression do
  @moduledoc """
  Implements various Linear Regression indicators.

  Linear Regression is a statistical technique used in technical analysis to identify
  and measure trend direction. This module provides implementations for:
  - Linear Regression Line
  - Linear Regression Slope
  - Linear Regression Channel (upper and lower bands)
  - R-squared (coefficient of determination)
  """

  alias Central.Backtest.Indicators.Calculations.ListOperations
  alias Central.Backtest.Indicators.Calculations.Math
  alias Central.Backtest.Indicators.Volatility.StdDev

  @doc """
  Calculates the Linear Regression Line.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to include in the regression (typically 20)
    - price_key: Key to use for price data (:close, :open, etc.)

  ## Returns
    - List of linear regression line values aligned with input candles
  """
  def regression_line(candles, period \\ 20, price_key \\ :close)
    when is_list(candles) and is_integer(period) and period > 0 do

    # Extract price data
    prices = ListOperations.extract_key(candles, price_key)

    # Calculate regression lines for rolling windows
    regression_values =
      prices
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn window ->
        {slope, intercept} = calculate_slope_intercept(window)

        # Regression line endpoint (predicted value at the last point in window)
        x = period - 1  # Zero-based index for the last point
        Decimal.add(intercept, Decimal.mult(slope, Decimal.new(x)))
      end)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(regression_values)
    List.duplicate(nil, padding_length) ++ regression_values
  end

  @doc """
  Calculates the Linear Regression Slope.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to include in the regression (typically 20)
    - price_key: Key to use for price data (:close, :open, etc.)
    - normalized: Whether to normalize the slope (default true)

  ## Returns
    - List of slope values aligned with input candles
  """
  def regression_slope(candles, period \\ 20, price_key \\ :close, normalized \\ true)
    when is_list(candles) and is_integer(period) and period > 0 and is_boolean(normalized) do

    # Extract price data
    prices = ListOperations.extract_key(candles, price_key)

    # Calculate slopes for rolling windows
    slope_values =
      prices
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn window ->
        {slope, _intercept} = calculate_slope_intercept(window)

        if normalized do
          # Normalize by average price to make slope comparable across different price scales
          avg_price = Math.average(window)

          # Convert to percentage per period
          if Decimal.equal?(avg_price, Decimal.new(0)) do
            Decimal.new(0)
          else
            Decimal.div(slope, avg_price) |> Decimal.mult(Decimal.new(100))
          end
        else
          slope
        end
      end)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(slope_values)
    List.duplicate(nil, padding_length) ++ slope_values
  end

  @doc """
  Calculates the Linear Regression Channel.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to include in the regression (typically 20)
    - deviations: Number of standard deviations for channel width (typically a value near 2)
    - price_key: Key to use for price data (:close, :open, etc.)

  ## Returns
    - List of maps containing channel values aligned with input candles:
      %{
        middle: value,  # Linear regression line
        upper: value,   # Upper channel line
        lower: value    # Lower channel line
      }
  """
  def regression_channel(candles, period \\ 20, deviations \\ 2, price_key \\ :close)
    when is_list(candles) and is_integer(period) and period > 0 and is_number(deviations) and deviations > 0 do

    # Extract price data
    prices = ListOperations.extract_key(candles, price_key)

    # Process each window
    channel_values =
      prices
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn window ->
        # Calculate regression parameters
        {slope, intercept} = calculate_slope_intercept(window)

        # Calculate regression line for each point in the window
        regression_points = calculate_regression_points(slope, intercept, period)

        # Calculate standard error (standard deviation of the residuals)
        std_error = calculate_standard_error(window, regression_points)

        # Get the regression line endpoint (last value)
        middle = List.last(regression_points)

        # Calculate channel boundaries
        decimal_deviations = Decimal.from_float(deviations)
        deviation_term = Decimal.mult(std_error, decimal_deviations)

        upper = Decimal.add(middle, deviation_term)
        lower = Decimal.sub(middle, deviation_term)

        %{
          middle: middle,
          upper: upper,
          lower: lower
        }
      end)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(channel_values)
    List.duplicate(nil, padding_length) ++ channel_values
  end

  @doc """
  Calculates the R-squared value (coefficient of determination).

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to include in the regression (typically 20)
    - price_key: Key to use for price data (:close, :open, etc.)

  ## Returns
    - List of R-squared values aligned with input candles (0 to 1, higher values indicate better fit)
  """
  def r_squared(candles, period \\ 20, price_key \\ :close)
    when is_list(candles) and is_integer(period) and period > 0 do

    # Extract price data
    prices = ListOperations.extract_key(candles, price_key)

    # Calculate R-squared for each window
    r_squared_values =
      prices
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn window ->
        # Calculate regression parameters
        {slope, intercept} = calculate_slope_intercept(window)

        # Calculate regression line for each point in the window
        regression_points = calculate_regression_points(slope, intercept, period)

        # Calculate R-squared
        calculate_r_squared(window, regression_points)
      end)

    # Align results with input data (pad with nils)
    padding_length = length(candles) - length(r_squared_values)
    List.duplicate(nil, padding_length) ++ r_squared_values
  end

  # Helper functions

  # Calculate slope and intercept for a given window of prices
  defp calculate_slope_intercept(prices) when length(prices) > 1 do
    n = length(prices)

    # Convert to list of {x, y} coordinates where x is the index
    coords = Enum.with_index(prices, fn price, index -> {Decimal.new(index), price} end)

    # Calculate sums for the least squares formula
    sum_x = Enum.reduce(coords, Decimal.new(0), fn {x, _}, acc -> Decimal.add(acc, x) end)
    sum_y = Enum.reduce(coords, Decimal.new(0), fn {_, y}, acc -> Decimal.add(acc, y) end)
    sum_xy = Enum.reduce(coords, Decimal.new(0), fn {x, y}, acc ->
      Decimal.add(acc, Decimal.mult(x, y))
    end)
    sum_x_squared = Enum.reduce(coords, Decimal.new(0), fn {x, _}, acc ->
      Decimal.add(acc, Decimal.mult(x, x))
    end)

    # Calculate slope
    decimal_n = Decimal.new(n)
    numerator = Decimal.sub(
      Decimal.mult(decimal_n, sum_xy),
      Decimal.mult(sum_x, sum_y)
    )
    denominator = Decimal.sub(
      Decimal.mult(decimal_n, sum_x_squared),
      Decimal.mult(sum_x, sum_x)
    )

    # Handle case where denominator is zero (horizontal line)
    slope = if Decimal.equal?(denominator, Decimal.new(0)) do
      Decimal.new(0)
    else
      Decimal.div(numerator, denominator)
    end

    # Calculate intercept
    intercept = Decimal.sub(
      Decimal.div(sum_y, decimal_n),
      Decimal.mult(
        slope,
        Decimal.div(sum_x, decimal_n)
      )
    )

    {slope, intercept}
  end

  # Calculate the linear regression line points for a given slope and intercept
  defp calculate_regression_points(slope, intercept, count) when count > 0 do
    Enum.map(0..(count - 1), fn x ->
      decimal_x = Decimal.new(x)
      Decimal.add(intercept, Decimal.mult(slope, decimal_x))
    end)
  end

  # Calculate the standard error (standard deviation of residuals)
  defp calculate_standard_error(actual_values, regression_values) when length(actual_values) == length(regression_values) do
    # Calculate residuals (actual - predicted)
    residuals = Enum.zip(actual_values, regression_values)
    |> Enum.map(fn {actual, predicted} ->
      Decimal.sub(actual, predicted)
    end)

    # Calculate standard deviation of residuals
    StdDev.calculate_std_dev(residuals)
  end

  # Calculate R-squared (coefficient of determination)
  defp calculate_r_squared(actual_values, regression_values) when length(actual_values) == length(regression_values) do
    # Calculate mean of actual values
    mean = Math.average(actual_values)

    # Calculate sum of squared residuals (SSR)
    ssr = Enum.zip(actual_values, regression_values)
    |> Enum.reduce(Decimal.new(0), fn {actual, predicted}, acc ->
      residual = Decimal.sub(actual, predicted)
      sq_residual = Decimal.mult(residual, residual)
      Decimal.add(acc, sq_residual)
    end)

    # Calculate total sum of squares (SST)
    sst = Enum.reduce(actual_values, Decimal.new(0), fn actual, acc ->
      diff = Decimal.sub(actual, mean)
      sq_diff = Decimal.mult(diff, diff)
      Decimal.add(acc, sq_diff)
    end)

    # R² = 1 - (SSR / SST)
    if Decimal.equal?(sst, Decimal.new(0)) do
      # If SST is zero, all values are the same, so R² is 1 (perfect fit)
      Decimal.new(1)
    else
      Decimal.sub(
        Decimal.new(1),
        Decimal.div(ssr, sst)
      )
    end
  end

  @doc """
  Finds potential support and resistance levels using linear regression.

  ## Parameters
    - candles: List of market data candles
    - threshold: Minimum R-squared value for a strong trend (0.7-0.8 typical)
    - min_length: Minimum length for a trend (typically 5-10 candles)
    - lookback: Number of candles to analyze for trends

  ## Returns
    - List of support and resistance levels with their strengths
  """
  def find_support_resistance(candles, threshold \\ 0.7, min_length \\ 5, lookback \\ 100) do
    # Limit the lookback to available candles
    actual_lookback = min(lookback, length(candles))
    recent_candles = Enum.take(candles, -actual_lookback)

    # Extract highs and lows
    highs = Enum.map(recent_candles, & &1.high)
    lows = Enum.map(recent_candles, & &1.low)

    # Find trends with high R-squared values
    high_trends = find_trend_segments(highs, threshold, min_length)
    low_trends = find_trend_segments(lows, threshold, min_length)

    # Project these trends to get potential levels
    high_projections = project_trends(high_trends, 10)
    low_projections = project_trends(low_trends, 10)

    # Combine and return results
    %{
      resistance: high_projections,
      support: low_projections
    }
  end

  # Find segments with strong trends (high R-squared)
  defp find_trend_segments(prices, threshold, min_length) do
    # Calculate for different segment lengths
    max_length = min_length + 20

    Enum.flat_map((min_length * 2)..max_length, fn segment_len ->
      prices
      |> Enum.chunk_every(segment_len, div(segment_len, 2), :discard)
      |> Enum.map(fn chunk ->
        # Calculate R-squared for this chunk
        {slope, intercept} = calculate_slope_intercept(chunk)
        regression_points = calculate_regression_points(slope, intercept, length(chunk))
        r2 = calculate_r_squared(chunk, regression_points)

        # If R-squared is above threshold, this is a strong trend
        if Decimal.compare(r2, Decimal.from_float(threshold)) == :gt do
          %{
            slope: slope,
            intercept: intercept,
            r_squared: r2,
            length: length(chunk),
            last_price: List.last(chunk)
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    end)
  end

  # Project trends forward to find potential support/resistance levels
  defp project_trends(trends, projection_periods) do
    Enum.map(trends, fn %{slope: slope, intercept: intercept, length: length, r_squared: r2} = trend ->
      # Project forward
      projected_value =
        (length + projection_periods - 1)  # Zero-based index
        |> Decimal.new()
        |> Decimal.mult(slope)
        |> Decimal.add(intercept)

      # Calculate strength based on R-squared and segment length
      strength = Decimal.mult(r2, Decimal.from_float(length / 10))

      Map.merge(trend, %{
        projected_level: projected_value,
        strength: strength
      })
    end)
    |> Enum.sort_by(fn %{strength: strength} -> Decimal.to_float(strength) end, :desc)
  end
end
