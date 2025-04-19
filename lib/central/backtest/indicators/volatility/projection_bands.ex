defmodule Central.Backtest.Indicators.Volatility.ProjectionBands do
  @moduledoc """
  Implements Projection Bands.

  Projection Bands are similar to Bollinger Bands but with optional adaptive band width
  calculation. The bands represent volatility by defining an envelope around a moving average.

  The calculation involves:
  1. Calculate a moving average (typically EMA)
  2. Calculate standard deviation of price from the moving average
  3. Upper band = MA + (multiplier * standard deviation)
  4. Lower band = MA - (multiplier * standard deviation)

  When adaptive is enabled, the multiplier is adjusted based on price volatility.

  ## Parameters

  - prices: List of price values
  - period: Number of periods for calculation (default: 20)
  - multiplier: Standard deviation multiplier (default: 2.0)
  - ma_type: Type of moving average to use (:sma, :ema, :wma) (default: :ema)
  - adaptive: Whether to use adaptive band calculation (default: false)

  ## Returns

  A tuple containing:
  - {:ok, {middle_band, upper_band, lower_band}} on success
  - {:error, reason} on failure
  """

  @doc """
  Calculates Projection Bands from raw price data or candle data.

  When passed a list of prices, calculates bands based on those values.
  When passed a list of candle maps, extracts prices using the specified price_key.
  """
  def calculate(prices, period \\ 20, multiplier \\ 2.0, ma_type \\ :ema, adaptive \\ false)

  def calculate(prices, period, multiplier, ma_type, adaptive) when is_list(prices) and not is_map(hd(prices)) do
    with true <- validate_inputs(prices, period, multiplier) do
      # Calculate the middle band (moving average)
      {:ok, middle_band} = calculate_middle_band(prices, period, ma_type)

      # Calculate standard deviation
      std_dev = calculate_std_dev(prices, middle_band, period)

      # Calculate projection factor (fixed or adaptive)
      projection_factor = if adaptive do
        calculate_adaptive_factor(prices, period, multiplier)
      else
        List.duplicate(multiplier, length(prices))
      end

      # Calculate upper and lower bands
      {upper_band, lower_band} = calculate_bands(middle_band, std_dev, projection_factor)

      {:ok, {middle_band, upper_band, lower_band}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def calculate(candles, period, multiplier, ma_type, adaptive)
      when is_list(candles) and is_map(hd(candles)) do
    calculate(candles, period, multiplier, ma_type, adaptive, :close)
  end

  def calculate(candles, period, multiplier, ma_type, adaptive, price_type)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_type) do

    prices = Enum.map(candles, &Map.get(&1, price_type))
    calculate(prices, period, multiplier, ma_type, adaptive)
  end

  defp validate_inputs(prices, period, multiplier) do
    cond do
      not is_list(prices) ->
        {:error, "Prices must be a list"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      multiplier <= 0 ->
        {:error, "Multiplier must be greater than 0"}
      length(prices) < period ->
        {:error, "Not enough data points for the given period"}
      true ->
        true
    end
  end

  defp calculate_middle_band(prices, period, ma_type) do
    case ma_type do
      :sma -> Central.Backtest.Indicators.Trend.MovingAverage.calculate(prices, period, :simple)
      :ema -> Central.Backtest.Indicators.Trend.ExponentialMovingAverage.calculate(prices, period)
      :wma -> Central.Backtest.Indicators.Trend.MovingAverage.calculate(prices, period, :weighted)
      _ -> {:error, "Unsupported moving average type"}
    end
  end

  defp calculate_std_dev(prices, middle_band, period) do
    prices
    |> Enum.zip(middle_band)
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      variance = Enum.reduce(chunk, 0, fn {price, ma}, acc ->
        diff = price - ma
        acc + (diff * diff)
      end) / length(chunk)
      :math.sqrt(variance)
    end)
    |> pad_with_zeros(length(prices), period - 1)
  end

  defp calculate_adaptive_factor(prices, period, base_multiplier) do
    # Calculate price volatility ratio to adjust the band width
    prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      # Calculate trend strength
      first = List.first(chunk)
      last = List.last(chunk)
      trend_change = abs(last - first) / first

      # Higher volatility = wider bands (up to 2x base_multiplier)
      # Lower volatility = narrower bands (down to 0.5x base_multiplier)
      min_factor = base_multiplier * 0.5
      max_factor = base_multiplier * 2.0

      # Scale trend_change to get adaptive factor
      scaled_factor = min_factor + (trend_change * 10)
      |> min(max_factor)
      |> max(min_factor)

      scaled_factor
    end)
    |> pad_with_last_value(length(prices), period - 1)
  end

  defp calculate_bands(middle_band, std_dev, projection_factor) do
    Enum.zip([middle_band, std_dev, projection_factor])
    |> Enum.map(fn {ma, sd, factor} ->
      band_width = sd * factor
      {ma + band_width, ma - band_width}
    end)
    |> Enum.unzip()
  end

  defp pad_with_zeros(values, original_length, padding_size) do
    padding = List.duplicate(0, padding_size)
    padding ++ values ++ List.duplicate(0, original_length - padding_size - length(values))
  end

  defp pad_with_last_value(values, original_length, padding_size) do
    last_value = List.last(values) || 0
    padding = List.duplicate(0, padding_size)
    padding ++ values ++ List.duplicate(last_value, original_length - padding_size - length(values))
  end

  @doc """
  Generates trading signals based on Projection Bands.

  Returns:
  - 1 for buy signal (price touches or crosses below lower band)
  - -1 for sell signal (price touches or crosses above upper band)
  - 0 for no signal
  """
  def generate_signals(prices, {_middle, upper, lower}) do
    Enum.zip([prices, upper, lower])
    |> Enum.map(fn {price, upper_band, lower_band} ->
      cond do
        price <= lower_band -> 1  # Buy signal
        price >= upper_band -> -1 # Sell signal
        true -> 0  # No signal
      end
    end)
  end

  @doc """
  Identifies contraction and expansion patterns in Projection Bands.

  Returns a list of band pattern events:
  - {:contraction, index} when bands are narrowing
  - {:expansion, index} when bands are widening
  - {:squeeze, index} when bands are extremely narrow
  """
  def identify_band_patterns({_middle, upper, lower}, threshold \\ 0.1) do
    band_widths = Enum.zip(upper, lower)
    |> Enum.map(fn {u, l} -> u - l end)

    # Calculate average band width
    avg_width = Enum.sum(band_widths) / length(band_widths)

    # Identify patterns
    band_widths
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
end
