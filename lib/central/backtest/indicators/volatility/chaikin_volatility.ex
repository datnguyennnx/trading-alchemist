defmodule Central.Backtest.Indicators.Volatility.ChaikinVolatility do
  @moduledoc """
  Implements the Chaikin Volatility indicator.

  Chaikin Volatility measures the rate of change of the trading range
  (high minus low) over a specified period. It is designed to increase
  when volatility rises and decrease when volatility falls, helping to
  identify potential market reversals.

  The calculation involves:
  1. Calculate the difference between high and low prices (trading range)
  2. Apply exponential moving average to the trading range
  3. Calculate the percentage rate of change of the smoothed trading range

  ## Parameters

  - high: List of high prices
  - low: List of low prices
  - ema_period: Number of periods for EMA smoothing (default: 10)
  - roc_period: Number of periods for rate of change calculation (default: 10)

  ## Returns

  A tuple containing:
  - {:ok, chaikin_volatility_values} on success
  - {:error, reason} on failure
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates the Chaikin Volatility indicator.
  """
  def calculate(high, low, ema_period \\ 10, roc_period \\ 10) do
    with true <- validate_inputs(high, low, ema_period, roc_period),
         range <- calculate_trading_range(high, low),
         smoothed_range <- MovingAverage.ema(range, ema_period),
         chaikin_volatility <- calculate_roc(smoothed_range, roc_period) do
      {:ok, chaikin_volatility}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(high, low, ema_period, roc_period) do
    cond do
      not is_list(high) or not is_list(low) ->
        {:error, "Inputs must be lists"}
      length(high) != length(low) ->
        {:error, "Input lists must have the same length"}
      ema_period <= 0 or roc_period <= 0 ->
        {:error, "Periods must be greater than 0"}
      true ->
        true
    end
  end

  defp calculate_trading_range(high, low) do
    Enum.zip(high, low)
    |> Enum.map(fn {h, l} -> h - l end)
  end

  defp calculate_roc(smoothed_range, roc_period) do
    smoothed_range
    |> Enum.chunk_every(roc_period + 1, 1, :discard)
    |> Enum.map(fn chunk ->
      [first | _] = chunk
      last = List.last(chunk)
      if first == 0, do: 0, else: (last - first) / first * 100
    end)
    |> pad_with_zeros(length(smoothed_range))
  end

  defp pad_with_zeros(values, original_length) do
    padding_length = original_length - length(values)
    if padding_length > 0 do
      List.duplicate(0, padding_length) ++ values
    else
      values
    end
  end

  @doc """
  Detects potential market reversals based on Chaikin Volatility.

  Returns a list of:
  - {:volatility_peak, index} when volatility peaks and starts declining
  - {:volatility_bottom, index} when volatility bottoms and starts rising
  """
  def detect_reversals(chaikin_volatility, threshold \\ 10, lookback \\ 5) do
    chaikin_volatility
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.flat_map(fn {window, index} ->
      detect_reversal_in_window(window, index, threshold)
    end)
  end

  defp detect_reversal_in_window(window, index, threshold) do
    middle_index = div(length(window), 2)
    middle_value = Enum.at(window, middle_index)
    left_values = Enum.take(window, middle_index)
    right_values = Enum.drop(window, middle_index + 1)

    cond do
      # Peak detection (values increasing then decreasing)
      Enum.all?(left_values, fn v -> v < middle_value end) and
      Enum.all?(right_values, fn v -> v < middle_value end) and
      middle_value > threshold ->
        [{:volatility_peak, index + middle_index}]

      # Bottom detection (values decreasing then increasing)
      Enum.all?(left_values, fn v -> v > middle_value end) and
      Enum.all?(right_values, fn v -> v > middle_value end) and
      abs(middle_value) < threshold ->
        [{:volatility_bottom, index + middle_index}]

      true ->
        []
    end
  end

  @doc """
  Classifies market conditions based on Chaikin Volatility.

  Returns:
  - :high_volatility when volatility exceeds the upper threshold
  - :normal_volatility when volatility is between thresholds
  - :low_volatility when volatility is below the lower threshold
  """
  def classify_market_condition(chaikin_volatility, upper_threshold \\ 15, lower_threshold \\ 5, window_size \\ 10) do
    recent_values = Enum.take(chaikin_volatility, -window_size)

    if length(recent_values) < window_size do
      {:error, "Not enough data points for analysis"}
    else
      avg_volatility = Enum.sum(recent_values) / window_size

      cond do
        avg_volatility > upper_threshold -> {:ok, :high_volatility}
        avg_volatility < lower_threshold -> {:ok, :low_volatility}
        true -> {:ok, :normal_volatility}
      end
    end
  end

  @doc """
  Calculates volatility bands around price based on Chaikin Volatility.

  Returns a map with keys:
  - :upper_band - Upper volatility band
  - :lower_band - Lower volatility band
  - :width_percentage - Band width as percentage of price
  """
  def calculate_bands(close, chaikin_volatility, multiplier \\ 1.0) do
    Enum.zip(close, chaikin_volatility)
    |> Enum.map(fn {price, volatility} ->
      # Convert volatility percentage to decimal for band calculation
      volatility_factor = abs(volatility) / 100 * multiplier
      band_width = price * volatility_factor

      %{
        upper_band: price + band_width,
        lower_band: price - band_width,
        width_percentage: volatility_factor * 100
      }
    end)
  end
end
