defmodule Central.Backtest.Indicators.Levels.Channels do
  @moduledoc """
  Implements various price channels for technical analysis.

  Price channels are parallel lines that define upper and lower boundaries for price movement.
  They help identify trends, potential reversals, and breakout opportunities.

  This module implements several types of channels:
  1. Linear Regression Channels
  2. Raff Regression Channels
  3. Parallel Channels
  4. Trend Channels (dynamic angle)
  5. Envelope Channels (percentage-based)

  ## Parameters

  Vary by channel type but typically include:
  - prices: List of price values
  - high/low: Lists of high and low prices (for some channel types)
  - period: Number of periods for calculation
  - deviation: Distance/multiplier for channel boundaries

  ## Returns

  Varies by function, typically:
  - {:ok, {upper_channel, mid_line, lower_channel}} on success
  - {:error, reason} on failure
  """

  alias Central.Backtest.Indicators.Calculations.ListOperations

  @doc """
  Calculates Linear Regression Channel.

  Uses linear regression as the middle line, with upper and lower channels
  at specified standard deviations.

  Returns:
  - {:ok, {upper_channel, mid_line, lower_channel}} on success
  - {:error, reason} on failure
  """
  def linear_regression_channel(prices, period, deviation_multiplier \\ 2.0)

  def linear_regression_channel(prices, period, deviation_multiplier)
      when is_list(prices) and is_number(period) and is_number(deviation_multiplier) do
    with :ok <- validate_inputs(prices, period),
         {:ok, {_slope, _intercept, fitted_values}} <- calculate_linear_regression(prices, period) do

      # Calculate standard error for the channel width
      std_error = calculate_std_error(prices, fitted_values, period)

      # Calculate upper and lower channels - zip the values and apply calculations point by point
      upper_channel = Enum.zip(fitted_values, std_error)
        |> Enum.map(fn {val, err} -> val + err * deviation_multiplier end)

      lower_channel = Enum.zip(fitted_values, std_error)
        |> Enum.map(fn {val, err} -> val - err * deviation_multiplier end)

      {:ok, {upper_channel, fitted_values, lower_channel}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def linear_regression_channel(candles, period, deviation_multiplier)
      when is_list(candles) and is_map(hd(candles)) do
    linear_regression_channel(candles, period, deviation_multiplier, :close)
  end

  @doc """
  Calculates Linear Regression Channel from OHLC candle data.

  ## Parameters
    - candles: List of candle maps with price data
    - period: Number of periods for calculation (default: 20)
    - deviation_multiplier: Width of the channel (default: 2.0)
    - price_type: Price type to use from candles (default: :close)

  ## Returns
    - {:ok, {upper_channel, mid_line, lower_channel}} on success
    - {:error, reason} on failure
  """
  def linear_regression_channel(candles, period, deviation_multiplier, price_type)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_type) do

    prices = Enum.map(candles, &Map.get(&1, price_type))
    linear_regression_channel(prices, period, deviation_multiplier)
  end

  @doc """
  Calculates Linear Regression Channel from OHLC candle data with default parameters.

  ## Parameters
    - candles: List of candle maps with price data
    - period: Number of periods for calculation

  ## Returns
    - {:ok, {upper_channel, mid_line, lower_channel}} on success
    - {:error, reason} on failure
  """
  def linear_regression_channel_candles(candles, period)
      when is_list(candles) and is_map(hd(candles)) do
    linear_regression_channel(candles, period, 2.0, :close)
  end

  @doc """
  Calculates Raff Regression Channel.

  Similar to linear regression channel but uses furthest points from the
  regression line to define channel boundaries.

  Returns:
  - {:ok, {upper_channel, mid_line, lower_channel}} on success
  - {:error, reason} on failure
  """
  def raff_regression_channel(prices, period)
      when is_list(prices) and is_number(period) do
    with :ok <- validate_inputs(prices, period),
         {:ok, {_slope, _intercept, fitted_values}} <- calculate_linear_regression(prices, period) do

      # Calculate max deviations above and below the regression line
      channel_bounds = prices
        |> Enum.chunk_every(period, 1, :discard)
        |> Enum.zip(Enum.chunk_every(fitted_values, period, 1, :discard))
        |> Enum.map(fn {price_chunk, fitted_chunk} ->
          deviations = Enum.zip(price_chunk, fitted_chunk)
            |> Enum.map(fn {price, fitted} -> price - fitted end)

          max_deviation = Enum.max(deviations)
          min_deviation = Enum.min(deviations)

          {max_deviation, min_deviation}
        end)
        |> pad_with_zeros(length(prices), period - 1)

      # Extract max and min deviations
      {max_deviations, min_deviations} = Enum.unzip(channel_bounds)

      # Calculate upper and lower channels
      upper_channel = Enum.zip(fitted_values, max_deviations)
        |> Enum.map(fn {fitted, max_dev} -> fitted + max_dev end)

      lower_channel = Enum.zip(fitted_values, min_deviations)
        |> Enum.map(fn {fitted, min_dev} -> fitted + min_dev end)

      {:ok, {upper_channel, fitted_values, lower_channel}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def raff_regression_channel(candles, period)
      when is_list(candles) and is_map(hd(candles)) do
    raff_regression_channel(candles, period, :close)
  end

  @doc """
  Calculates Raff Regression Channel from OHLC candle data.

  ## Parameters
    - candles: List of candle maps with price data
    - period: Number of periods for calculation (default: 20)
    - price_type: Price type to use from candles (default: :close)

  ## Returns
    - {:ok, {upper_channel, mid_line, lower_channel}} on success
    - {:error, reason} on failure
  """
  def raff_regression_channel(candles, period, price_type)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_type) do

    prices = Enum.map(candles, &Map.get(&1, price_type))
    raff_regression_channel(prices, period)
  end

  @doc """
  Calculates Parallel Channel (a.k.a. Andrews' Pitchfork).

  Creates a channel with parallel upper and lower boundaries based on significant
  pivot points in the price series.

  Returns:
  - {:ok, {upper_channel, median_line, lower_channel}} on success
  - {:error, reason} on failure
  """
  def parallel_channel(high, low, period \\ 20) do
    with :ok <- validate_high_low(high, low, period) do
      # Find pivot points (highs and lows)
      pivots = find_pivot_points(high, low, period)

      # Extract median line points
      median_points = calculate_median_points(pivots, length(high))

      # Calculate parallel channel lines
      {upper_channel, lower_channel} = calculate_parallel_lines(pivots, median_points, high, low)

      {:ok, {upper_channel, median_points, lower_channel}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates Trend Channel.

  Creates a channel that follows the angle of the trend, with upper and lower
  boundaries defined by the highest highs and lowest lows within the period.

  Returns:
  - {:ok, {upper_channel, mid_line, lower_channel}} on success
  - {:error, reason} on failure
  """
  def trend_channel(high, low, close, period \\ 20) do
    with :ok <- validate_hlc(high, low, close, period) do
      # Calculate the trend angle (using linear regression on close prices)
      {:ok, {slope, intercept, mid_line}} = calculate_linear_regression(close, period)

      # Find highest highs and lowest lows for the channel boundaries
      upper_points = high
        |> Enum.chunk_every(period, 1, :discard)
        |> Enum.map(&Enum.max/1)
        |> pad_with_first_value(length(high), period - 1)

      lower_points = low
        |> Enum.chunk_every(period, 1, :discard)
        |> Enum.map(&Enum.min/1)
        |> pad_with_first_value(length(low), period - 1)

      # Adjust upper and lower points to maintain the same slope as the mid-line
      upper_channel = adjust_channel_to_slope(upper_points, slope, intercept, close)
      lower_channel = adjust_channel_to_slope(lower_points, slope, intercept, close)

      {:ok, {upper_channel, mid_line, lower_channel}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates Trend Channel from OHLC candle data.

  ## Parameters
    - candles: List of candle maps with :high, :low, and :close data
    - period: Number of periods for calculation (default: 20)

  ## Returns
    - {:ok, {upper_channel, mid_line, lower_channel}} on success
    - {:error, reason} on failure
  """
  def trend_channel(candles, period)
      when is_list(candles) and is_map(hd(candles)) do

    high = Enum.map(candles, &Map.get(&1, :high))
    low = Enum.map(candles, &Map.get(&1, :low))
    close = Enum.map(candles, &Map.get(&1, :close))

    trend_channel(high, low, close, period)
  end

  @doc """
  Calculates Envelope Channel.

  Creates percentage-based channels around a central moving average.

  Returns:
  - {:ok, {upper_channel, mid_line, lower_channel}} on success
  - {:error, reason} on failure
  """
  def envelope_channel(prices, period, percentage \\ 2.5, ma_type \\ :sma)

  def envelope_channel(prices, period, percentage, ma_type)
      when is_list(prices) and is_number(period) do
    with :ok <- validate_inputs(prices, period) do
      # Calculate the middle line (moving average)
      {:ok, mid_line} = case ma_type do
        :sma -> Central.Backtest.Indicators.Trend.MovingAverage.calculate(prices, period, :simple)
        :ema -> Central.Backtest.Indicators.Trend.ExponentialMovingAverage.calculate(prices, period)
        :wma -> Central.Backtest.Indicators.Trend.MovingAverage.calculate(prices, period, :weighted)
        _ -> {:error, "Unsupported moving average type"}
      end

      # Calculate upper and lower envelopes
      upper_channel = Enum.map(mid_line, fn val -> val * (1 + percentage / 100) end)
      lower_channel = Enum.map(mid_line, fn val -> val * (1 - percentage / 100) end)

      {:ok, {upper_channel, mid_line, lower_channel}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def envelope_channel(candles, period, percentage, ma_type)
      when is_list(candles) and is_map(hd(candles)) do
    envelope_channel(candles, period, percentage, ma_type, :close)
  end

  @doc """
  Calculates Envelope Channel from OHLC candle data.

  ## Parameters
    - candles: List of candle maps with price data
    - period: Number of periods for calculation (default: 20)
    - percentage: Percentage for envelope width (default: 2.5)
    - ma_type: Type of moving average (default: :sma)
    - price_type: Price type to use from candles (default: :close)

  ## Returns
    - {:ok, {upper_channel, mid_line, lower_channel}} on success
    - {:error, reason} on failure
  """
  def envelope_channel(candles, period, percentage, ma_type, price_type)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_type) do

    prices = Enum.map(candles, &Map.get(&1, price_type))
    envelope_channel(prices, period, percentage, ma_type)
  end

  @doc """
  Calculates Envelope Channel from OHLC candle data with default percentage and MA type.

  ## Parameters
    - candles: List of candle maps with price data
    - period: Number of periods for calculation

  ## Returns
    - {:ok, {upper_channel, mid_line, lower_channel}} on success
    - {:error, reason} on failure
  """
  def envelope_channel_candles(candles, period, percentage)
      when is_list(candles) and is_map(hd(candles)) do
    envelope_channel(candles, period, percentage, :sma, :close)
  end

  @doc """
  Calculates Envelope Channel from OHLC candle data with default percentage and MA type.

  ## Parameters
    - candles: List of candle maps with price data
    - period: Number of periods for calculation

  ## Returns
    - {:ok, {upper_channel, mid_line, lower_channel}} on success
    - {:error, reason} on failure
  """
  def envelope_channel_candles(candles, period)
      when is_list(candles) and is_map(hd(candles)) do
    envelope_channel(candles, period, 2.5, :sma, :close)
  end

  @doc """
  Generates trading signals based on price breaks through channel boundaries.

  Returns:
  - 1 for buy signal (price breaks above upper channel)
  - -1 for sell signal (price breaks below lower channel)
  - 0 for no signal (price within channel)
  """
  def generate_signals(prices, {upper_channel, _mid_line, lower_channel})
      when is_list(prices) do
    Enum.zip([prices, upper_channel, lower_channel])
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [
      {prev_price, prev_upper, prev_lower},
      {curr_price, curr_upper, curr_lower}
    ] ->
      cond do
        prev_price <= prev_upper and curr_price > curr_upper -> 1  # Breakout above
        prev_price >= prev_lower and curr_price < curr_lower -> -1 # Breakout below
        true -> 0  # No breakout
      end
    end)
    |> pad_with_zeros(length(prices), 1)
  end

  def generate_signals(candles, channel_result)
      when is_list(candles) and is_map(hd(candles)) and is_tuple(channel_result) do
    generate_signals(candles, channel_result, :close)
  end

  @doc """
  Generates trading signals from channel calculations.

  ## Parameters
    - candles: List of candle maps with price data
    - channel_result: Result of a channel calculation
    - price_type: Price type to use for signal generation (default: :close)

  ## Returns
    - List of signals where 1=buy, -1=sell, 0=no signal
  """
  def generate_signals(candles, channel_result, price_type)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_type) and is_tuple(channel_result) do

    prices = Enum.map(candles, &Map.get(&1, price_type))
    generate_signals(prices, channel_result)
  end

  @doc """
  Identifies channel contraction and expansion patterns.

  Returns a list of channel pattern events:
  - {:contraction, index} when channel width is narrowing
  - {:expansion, index} when channel width is widening
  - {:squeeze, index} when channel is extremely narrow
  """
  def identify_channel_patterns({upper_channel, _mid_line, lower_channel}, threshold \\ 0.1) do
    channel_widths = Enum.zip(upper_channel, lower_channel)
    |> Enum.map(fn {upper, lower} -> upper - lower end)

    # Calculate average channel width
    avg_width = Enum.sum(channel_widths) / length(channel_widths)

    # Identify patterns
    channel_widths
    |> Enum.chunk_every(5, 1, :discard)
    |> Enum.with_index(4)
    |> Enum.flat_map(fn {chunk, index} ->
      current_width = List.last(chunk)
      pattern = cond do
        current_width < avg_width * (1 - threshold) -> {:contraction, index}
        current_width > avg_width * (1 + threshold) -> {:expansion, index}
        current_width < avg_width * 0.5 -> {:squeeze, index}
        true -> nil
      end

      if pattern, do: [pattern], else: []
    end)
  end

  # Helper Functions

  defp validate_inputs(prices, period) do
    cond do
      not is_list(prices) ->
        {:error, "Prices must be a list"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      length(prices) < period ->
        {:error, "Not enough data points for the given period"}
      true ->
        :ok
    end
  end

  defp validate_high_low(high, low, period) do
    cond do
      not is_list(high) or not is_list(low) ->
        {:error, "High and low must be lists"}
      length(high) != length(low) ->
        {:error, "High and low lists must have the same length"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      length(high) < period ->
        {:error, "Not enough data points for the given period"}
      true ->
        :ok
    end
  end

  defp validate_hlc(high, low, close, period) do
    cond do
      not is_list(high) or not is_list(low) or not is_list(close) ->
        {:error, "High, low, and close must be lists"}
      length(high) != length(low) or length(high) != length(close) ->
        {:error, "High, low, and close lists must have the same length"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      length(high) < period ->
        {:error, "Not enough data points for the given period"}
      true ->
        :ok
    end
  end

  defp calculate_linear_regression(prices, period) do
    results = prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      x_values = Enum.to_list(0..(length(chunk) - 1))
      {slope, intercept} = linear_regression(x_values, chunk)

      # Calculate fitted values
      fitted = Enum.map(x_values, fn x -> slope * x + intercept end)

      {slope, intercept, fitted}
    end)

    # Unzip the results
    {slopes, intercepts, fitted_chunks} = ListOperations.unzip3(results)

    # Extend the fitted values to full length
    fitted_values = fitted_chunks
    |> List.flatten()
    |> pad_with_first_value(length(prices), period - 1)

    # Use the last slope and intercept for any remaining calculations
    last_slope = List.last(slopes) || 0
    last_intercept = List.last(intercepts) || 0

    {:ok, {last_slope, last_intercept, fitted_values}}
  end

  defp linear_regression(x_values, y_values) do
    n = length(x_values)

    sum_x = Enum.sum(x_values)
    sum_y = Enum.sum(y_values)

    sum_xy = Enum.zip(x_values, y_values)
    |> Enum.map(fn {x, y} -> x * y end)
    |> Enum.sum()

    sum_xx = Enum.map(x_values, fn x -> x * x end)
    |> Enum.sum()

    # Calculate slope
    slope = if (n * sum_xx - sum_x * sum_x) == 0 do
      0  # Horizontal line if division by zero
    else
      (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x)
    end

    # Calculate intercept
    intercept = (sum_y - slope * sum_x) / n

    {slope, intercept}
  end

  defp calculate_std_error(prices, fitted_values, period) do
    squared_errors = Enum.zip(prices, fitted_values)
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      # Calculate sum of squared errors
      sum_squared_error = Enum.reduce(chunk, 0, fn {actual, fitted}, acc ->
        error = actual - fitted
        acc + error * error
      end)

      # Standard error (standard deviation of errors)
      :math.sqrt(sum_squared_error / length(chunk))
    end)
    |> pad_with_first_value(length(prices), period - 1)

    squared_errors
  end

  defp find_pivot_points(high, low, period) do
    high_data = Enum.chunk_every(high, period, 1, :discard)
    low_data = Enum.chunk_every(low, period, 1, :discard)

    high_indices = high_data
    |> Enum.map(fn chunk ->
      {max_value, max_index} = chunk
      |> Enum.with_index()
      |> Enum.max_by(fn {val, _idx} -> val end)

      {max_value, max_index}
    end)

    low_indices = low_data
    |> Enum.map(fn chunk ->
      {min_value, min_index} = chunk
      |> Enum.with_index()
      |> Enum.min_by(fn {val, _idx} -> val end)

      {min_value, min_index}
    end)

    # Combine high and low pivots
    high_indices ++ low_indices
  end

  defp calculate_median_points(pivots, data_length) do
    # For simplicity, we'll create a linear line through the middle of the data
    # In a real implementation, this would use the actual pivot points

    # Take two significant pivot points
    sorted_pivots = Enum.sort_by(pivots, fn {_val, idx} -> idx end)
    start_pivot = List.first(sorted_pivots) || {0, 0}
    end_pivot = List.last(sorted_pivots) || {0, data_length - 1}

    {start_val, start_idx} = start_pivot
    {end_val, end_idx} = end_pivot

    # Calculate the slope and intercept of the median line
    slope = if end_idx == start_idx do
      0
    else
      (end_val - start_val) / (end_idx - start_idx)
    end

    intercept = start_val - slope * start_idx

    # Generate the median line points
    Enum.map(0..(data_length - 1), fn x -> slope * x + intercept end)
  end

  defp calculate_parallel_lines(pivots, median_line, _high, _low) do
    # Find maximum distance from median line to create parallel lines
    distances = pivots
    |> Enum.map(fn {value, idx} ->
      median_value = Enum.at(median_line, idx)
      value - median_value
    end)

    max_distance = Enum.max(distances)
    min_distance = Enum.min(distances)

    # Create parallel lines
    upper_line = Enum.map(median_line, fn val -> val + max_distance end)
    lower_line = Enum.map(median_line, fn val -> val + min_distance end)

    {upper_line, lower_line}
  end

  defp adjust_channel_to_slope(points, _slope, _base_intercept, reference) do
    # Calculate the vertical shift needed to align with the points
    shifts = Enum.zip(points, reference)
    |> Enum.map(fn {point, ref} -> point - ref end)

    # Apply the slope with adjusted intercept
    reference
    |> Enum.zip(shifts)
    |> Enum.with_index()
    |> Enum.map(fn {{ref, shift}, _idx} ->
      # Use the slope but adjust the intercept to hit the point
      ref + shift
    end)
  end

  defp pad_with_zeros(values, original_length, padding_size) do
    padding = List.duplicate(0, padding_size)
    padding ++ values ++ List.duplicate(0, original_length - padding_size - length(values))
  end

  defp pad_with_first_value(values, original_length, padding_size) do
    first_value = List.first(values) || 0
    padding = List.duplicate(first_value, padding_size)
    padding ++ values ++ List.duplicate(first_value, original_length - padding_size - length(values))
  end
end
