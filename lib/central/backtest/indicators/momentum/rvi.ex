defmodule Central.Backtest.Indicators.Momentum.Rvi do
  @moduledoc """
  Implementation of the Relative Vigor Index (RVI) indicator.

  The Relative Vigor Index (RVI) measures the conviction of a recent price action
  and the likelihood that it will continue. It is based on the premise that prices
  tend to close higher than they open in uptrends, and close lower than they open in downtrends.

  The RVI compares the position of the close relative to the open with the trading range
  (high - low) over a specified period. A signal line is calculated as a moving average of the RVI.
  """

  alias Central.Backtest.Indicators.Calculations.Math
  alias Central.Backtest.Indicators.IndicatorUtils

  @doc """
  Calculates the Relative Vigor Index (RVI) for a given list of OHLCV data.

  The RVI measures the strength of a trend by comparing the position of the
  closing price relative to the opening price along with the trading range of the period.

  ## Parameters
    - data: List of OHLCV data
    - options: Optional parameters
      - period: Number of periods for calculation (default: 10)
      - signal_period: Number of periods for signal line (default: 4)

  ## Returns
    - List of maps containing RVI and signal values
  """
  @spec calculate(list(), keyword()) :: list()
  def calculate(data, options \\ [])

  def calculate(data, options) do
    period = Keyword.get(options, :period, 10)
    signal_period = Keyword.get(options, :signal_period, 4)

    opens = IndicatorUtils.extract_price(data, :open)
    highs = IndicatorUtils.extract_price(data, :high)
    lows = IndicatorUtils.extract_price(data, :low)
    closes = IndicatorUtils.extract_price(data, :close)

    # Calculate numerators and denominators
    numerators =
      Enum.zip_with([opens, highs, lows, closes], fn [o, h, l, c] ->
        if all_valid?([o, h, l, c]), do: Decimal.sub(c, o), else: nil
      end)

    denominators =
      Enum.zip_with([opens, highs, lows, closes], fn [o, h, l, c] ->
        if all_valid?([o, h, l, c]), do: Decimal.sub(h, l), else: nil
      end)

    # Calculate moving averages
    numerator_ma = calculate_swma(numerators, period)
    denominator_ma = calculate_swma(denominators, period)

    # Calculate RVI
    rvi_values =
      Enum.zip_with([numerator_ma, denominator_ma], fn
        [num, denom] when not is_nil(num) and not is_nil(denom) ->
          # Move Decimal operations out of the guard clause
          if not Decimal.equal?(denom, Decimal.new(0)) do
            Math.safe_div(num, denom)
          else
            nil
          end
        _ -> nil
      end)

    # Calculate signal line (4-period SMA of RVI)
    signal_values = IndicatorUtils.sma(rvi_values, signal_period)

    # Combine results
    Enum.zip_with([rvi_values, signal_values], fn
      [rvi, signal] -> %{rvi: rvi, signal: signal}
      _ -> %{rvi: nil, signal: nil}
    end)
  end

  # Check if all values in list are valid (not nil)
  defp all_valid?(values) do
    Enum.all?(values, &(not is_nil(&1)))
  end

  # Symmetrically Weighted Moving Average implementation for RVI
  defp calculate_swma(data, period) do
    data
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      if Enum.all?(chunk, &(not is_nil(&1))) do
        # Use weighted formula for SWMA
        {weighted_sum, weight_sum} =
          chunk
          |> Enum.with_index()
          |> Enum.reduce({Decimal.new(0), 0}, fn {value, idx}, {sum, weight_sum} ->
            weight =
              cond do
                idx < div(period, 2) -> idx + 1
                true -> period - idx
              end
            {Decimal.add(sum, Decimal.mult(value, Decimal.new(weight))), weight_sum + weight}
          end)

        if weight_sum > 0, do: Decimal.div(weighted_sum, Decimal.new(weight_sum)), else: nil
      else
        nil
      end
    end)
    |> IndicatorUtils.pad_beginning(period - 1)
  end

  @doc """
  Generates trading signals based on RVI and its signal line.

  ## Parameters
    - rvi_data: List of RVI result maps from calculate/2
    - use_histogram: Whether to generate signals based on histogram crossover (default: true)

  ## Returns
    - {:ok, signals} where signals is a list of:
      - 1 for buy signal
      - -1 for sell signal
      - 0 for no signal
  """
  def generate_signals(rvi_data, use_histogram \\ true) do
    signals =
      rvi_data
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn
        [nil, _] -> 0
        [_, nil] -> 0
        [prev, curr] ->
          cond do
            is_nil(prev[:rvi]) or is_nil(curr[:rvi]) or
            is_nil(prev[:signal]) or is_nil(curr[:signal]) ->
              0

            use_histogram ->
              # Calculate histogram values
              prev_hist = Decimal.sub(prev[:rvi], prev[:signal])
              curr_hist = Decimal.sub(curr[:rvi], curr[:signal])

              cond do
                Decimal.lt?(prev_hist, Decimal.new(0)) and Decimal.gt?(curr_hist, Decimal.new(0)) -> 1
                Decimal.gt?(prev_hist, Decimal.new(0)) and Decimal.lt?(curr_hist, Decimal.new(0)) -> -1
                true -> 0
              end

            true ->
              # Use RVI/signal line crossover for signals
              prev_rvi = prev[:rvi]
              prev_signal = prev[:signal]
              curr_rvi = curr[:rvi]
              curr_signal = curr[:signal]

              cond do
                Decimal.lt?(prev_rvi, prev_signal) and Decimal.gt?(curr_rvi, curr_signal) -> 1
                Decimal.gt?(prev_rvi, prev_signal) and Decimal.lt?(curr_rvi, curr_signal) -> -1
                true -> 0
              end
          end
      end)
      |> List.insert_at(0, 0)  # Add placeholder for first candle

    {:ok, signals}
  end

  @doc """
  Detects divergences between price and RVI.

  ## Parameters
    - candles: List of candle maps with price data
    - rvi_data: List of RVI result maps from calculate/2
    - lookback: Number of periods to look back for divergence detection (default: 10)

  ## Returns
    - {:ok, divergences} where divergences is a list of:
      - {:bullish_divergence, index} when price makes lower low but RVI makes higher low
      - {:bearish_divergence, index} when price makes higher high but RVI makes lower high
  """
  def detect_divergences(candles, rvi_data, lookback \\ 10) do
    # Ensure we have enough data
    if length(candles) < lookback * 2 or length(rvi_data) < lookback * 2 do
      {:ok, []}
    else
      highs = IndicatorUtils.extract_price(candles, :high)
      lows = IndicatorUtils.extract_price(candles, :low)

      rvi_values = Enum.map(rvi_data, fn
        nil -> nil
        %{rvi: rvi} -> rvi
        val -> val  # Handle raw RVI values case
      end)

      divergences =
        Enum.with_index(candles)
        |> Enum.drop(lookback)  # Skip first lookback candles
        |> Enum.flat_map(fn {_, idx} ->
          if idx + lookback < length(candles) do
            # Define the window for analysis
            window_price_highs = Enum.slice(highs, idx - lookback, lookback * 2)
            window_price_lows = Enum.slice(lows, idx - lookback, lookback * 2)
            window_rvi = Enum.slice(rvi_values, idx - lookback, lookback * 2)

            # Ignore windows with nil RVI values
            if Enum.any?(window_rvi, &is_nil/1) do
              []
            else
              # Find local peaks and troughs
              current_high = Enum.max_by(window_price_highs, fn val -> Decimal.to_float(val) end)
              current_low = Enum.min_by(window_price_lows, fn val -> Decimal.to_float(val) end)

              current_rvi_high = Enum.max_by(window_rvi, fn val -> Decimal.to_float(val) end)
              current_rvi_low = Enum.min_by(window_rvi, fn val -> Decimal.to_float(val) end)

              # Check for divergences
              all_divergences = []

              # Bullish divergence: lower price lows but higher RVI lows
              price_low_comparison = Decimal.compare(current_low, Enum.at(window_price_lows, 0))
              rvi_low_comparison = Decimal.compare(current_rvi_low, Enum.at(window_rvi, 0))

              all_divergences = if price_low_comparison == :lt and rvi_low_comparison == :gt do
                [{:bullish_divergence, idx} | all_divergences]
              else
                all_divergences
              end

              # Bearish divergence: higher price highs but lower RVI highs
              price_high_comparison = Decimal.compare(current_high, Enum.at(window_price_highs, 0))
              rvi_high_comparison = Decimal.compare(current_rvi_high, Enum.at(window_rvi, 0))

              all_divergences = if price_high_comparison == :gt and rvi_high_comparison == :lt do
                [{:bearish_divergence, idx} | all_divergences]
              else
                all_divergences
              end

              all_divergences
            end
          else
            []
          end
        end)

      {:ok, divergences}
    end
  end

  @doc """
  Convenience function for calculating RVI with given parameters.

  ## Parameters
    - candles: List of OHLCV data
    - period: Number of periods for calculation (default: 10)
    - signal_period: Number of periods for signal line (default: 4)

  ## Returns
    - {:ok, rvi_data} where rvi_data is a list of maps containing RVI values
  """
  def rvi(candles, period \\ 10, signal_period \\ 4) do
    result = calculate(candles, [period: period, signal_period: signal_period])
    {:ok, result}
  end
end
