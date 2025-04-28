defmodule Central.Backtest.Indicators.Volume.Mfi do
  @moduledoc """
  Implementation of the Money Flow Index (MFI) indicator.

  The Money Flow Index (MFI) is a volume-weighted momentum oscillator that measures the flow of money
  into and out of a security over a specified period. It is also known as volume-weighted RSI.

  MFI is used to identify overbought or oversold conditions and potential reversals. It ranges from 0 to 100:
  - Values above 80 indicate overbought conditions
  - Values below 20 indicate oversold conditions
  - Divergences between MFI and price can signal potential reversals

  The MFI calculation involves:
  1. Calculating the typical price for each period
  2. Determining money flow (typical price × volume)
  3. Classifying money flow as positive or negative based on price movement
  4. Calculating the money ratio and the MFI value
  """

  @doc """
  Calculates the Money Flow Index (MFI) for a list of candles.

  ## Parameters
    - candles: List of candle maps with price and volume data
    - period: Number of periods to use for calculation (default: 14)

  ## Returns
    - List of MFI values, one for each candle (first n values will be nil)
  """
  def mfi(candles, period \\ 14) do
    # Need at least period+1 candles to calculate MFI
    if length(candles) <= period do
      List.duplicate(nil, length(candles))
    else
      # Calculate typical price and raw money flow for each candle
      typical_prices_and_flows =
        Enum.map(candles, fn candle ->
          typical_price = (candle.high + candle.low + candle.close) / 3
          raw_money_flow = typical_price * candle.volume
          {typical_price, raw_money_flow}
        end)

      # Calculate MFI for each period
      Enum.with_index(typical_prices_and_flows)
      |> Enum.map(fn {{_current_typical_price, _}, index} ->
        if index < period do
          nil
        else
          # Get the data for the current period
          period_slice = Enum.slice(typical_prices_and_flows, (index - period)..index)

          # Calculate positive and negative money flows
          {positive_flow, negative_flow} =
            Enum.zip(Enum.slice(period_slice, 0, period), Enum.slice(period_slice, 1, period))
            |> Enum.reduce({0, 0}, fn {{prev_price, _prev_flow}, {curr_price, curr_flow}},
                                      {pos, neg} ->
              cond do
                curr_price > prev_price -> {pos + curr_flow, neg}
                curr_price < prev_price -> {pos, neg + curr_flow}
                # Equal prices - no change
                true -> {pos, neg}
              end
            end)

          # Calculate money ratio and MFI
          if negative_flow == 0 do
            # Avoid division by zero
            100.0
          else
            money_ratio = positive_flow / negative_flow
            100.0 - 100.0 / (1.0 + money_ratio)
          end
        end
      end)
    end
  end

  @doc """
  Calculates MFI and returns a structured result with trading signals.

  ## Parameters
    - candles: List of candle maps with price and volume data
    - period: Number of periods to use for calculation (default: 14)
    - overbought_threshold: Threshold for overbought condition (default: 80)
    - oversold_threshold: Threshold for oversold condition (default: 20)

  ## Returns
    - List of maps, each containing:
      - :timestamp - Timestamp from the candle
      - :mfi - The MFI value
      - :typical_price - The typical price used for calculation
      - :signal - Trading signal based on MFI value (:overbought, :oversold, or :neutral)
  """
  def calculate(candles, period \\ 14, overbought_threshold \\ 80, oversold_threshold \\ 20) do
    mfi_values = mfi(candles, period)

    Enum.zip(candles, mfi_values)
    |> Enum.map(fn {candle, mfi_value} ->
      typical_price = (candle.high + candle.low + candle.close) / 3

      signal =
        cond do
          is_nil(mfi_value) -> :insufficient_data
          mfi_value >= overbought_threshold -> :overbought
          mfi_value <= oversold_threshold -> :oversold
          true -> :neutral
        end

      %{
        timestamp: candle.timestamp,
        mfi: mfi_value,
        typical_price: typical_price,
        signal: signal
      }
    end)
  end

  @doc """
  Analyzes MFI data to identify divergences and potential trading signals.

  ## Parameters
    - mfi_data: List of MFI result maps from calculate/4

  ## Returns
    - List of maps with enhanced analysis for each period
  """
  def analyze(mfi_data) do
    mfi_data
    |> Enum.with_index()
    |> Enum.map(fn {point, index} ->
      if index >= 5 do
        prev_points = Enum.slice(mfi_data, (index - 5)..(index - 1))
        valid_points = Enum.filter(prev_points, &(not is_nil(&1.mfi)))

        # Check for MFI trend
        mfi_trend =
          if length(valid_points) >= 3 and not is_nil(point.mfi) do
            prev_mfi = Enum.map(valid_points, & &1.mfi)
            mfi_increasing = List.last(prev_mfi) < point.mfi

            cond do
              # MFI moving above 50 = bullish
              point.mfi > 50 and mfi_increasing -> :bullish
              # MFI above 50 but decreasing = weakening bullish
              point.mfi > 50 and not mfi_increasing -> :weakening_bullish
              # MFI below 50 but increasing = weakening bearish
              point.mfi < 50 and mfi_increasing -> :weakening_bearish
              # MFI below 50 and decreasing = bearish
              point.mfi < 50 and not mfi_increasing -> :bearish
              true -> :neutral
            end
          else
            :insufficient_data
          end

        # Check for overbought/oversold conditions
        extreme_condition =
          if not is_nil(point.mfi) do
            cond do
              point.mfi >= 80 -> :extremely_overbought
              point.mfi >= 70 -> :overbought
              point.mfi <= 20 -> :extremely_oversold
              point.mfi <= 30 -> :oversold
              true -> :normal_range
            end
          else
            :insufficient_data
          end

        # Check for failure swings
        failure_swing =
          if length(valid_points) >= 4 and not is_nil(point.mfi) do
            mfi_values = Enum.map(valid_points, & &1.mfi) ++ [point.mfi]

            cond do
              # Bullish failure swing: MFI falls below 20, rallies, pulls back but stays above 20, then rises
              Enum.any?(Enum.take(mfi_values, 2), &(&1 <= 20)) and
                Enum.all?(Enum.drop(mfi_values, 2), &(&1 > 20)) and
                  List.last(mfi_values) > Enum.at(mfi_values, -2) ->
                :bullish_failure_swing

              # Bearish failure swing: MFI rises above 80, drops, bounces but stays below 80, then falls
              Enum.any?(Enum.take(mfi_values, 2), &(&1 >= 80)) and
                Enum.all?(Enum.drop(mfi_values, 2), &(&1 < 80)) and
                  List.last(mfi_values) < Enum.at(mfi_values, -2) ->
                :bearish_failure_swing

              true ->
                :none
            end
          else
            :none
          end

        # Check for divergences
        divergence =
          if length(valid_points) >= 4 and not is_nil(point.mfi) do
            prices = Enum.map(valid_points, & &1.typical_price) ++ [point.typical_price]
            mfi_values = Enum.map(valid_points, & &1.mfi) ++ [point.mfi]

            price_higher_high =
              List.last(prices) > Enum.max(Enum.take(prices, length(prices) - 1))

            price_lower_low = List.last(prices) < Enum.min(Enum.take(prices, length(prices) - 1))

            mfi_higher_high =
              List.last(mfi_values) > Enum.max(Enum.take(mfi_values, length(mfi_values) - 1))

            mfi_lower_low =
              List.last(mfi_values) < Enum.min(Enum.take(mfi_values, length(mfi_values) - 1))

            cond do
              # Bearish divergence: Price makes higher high but MFI makes lower high
              price_higher_high and not mfi_higher_high -> :bearish_divergence
              # Bullish divergence: Price makes lower low but MFI makes higher low
              price_lower_low and not mfi_lower_low -> :bullish_divergence
              true -> :none
            end
          else
            :none
          end

        # Generate trading advice
        trading_advice =
          cond do
            failure_swing == :bullish_failure_swing -> :strong_buy
            failure_swing == :bearish_failure_swing -> :strong_sell
            divergence == :bullish_divergence -> :buy
            divergence == :bearish_divergence -> :sell
            extreme_condition == :extremely_overbought -> :strong_sell
            extreme_condition == :extremely_oversold -> :strong_buy
            extreme_condition == :overbought -> :consider_sell
            extreme_condition == :oversold -> :consider_buy
            mfi_trend == :bullish -> :hold_buy
            mfi_trend == :bearish -> :hold_sell
            true -> :hold
          end

        Map.merge(point, %{
          mfi_trend: mfi_trend,
          extreme_condition: extreme_condition,
          failure_swing: failure_swing,
          divergence: divergence,
          trading_advice: trading_advice
        })
      else
        Map.put(point, :trading_advice, :insufficient_data)
      end
    end)
  end

  @doc """
  Detects divergences between price and MFI values.

  ## Parameters
    - candles: List of candle maps with price data
    - mfi_data: List of MFI result maps from calculate/4
    - lookback: Number of periods to look back for divergence detection (default: 5)

  ## Returns
    - {:ok, divergences} where divergences is a list of divergence events:
      - {:bullish_divergence, index} when price makes lower low but MFI makes higher low
      - {:bearish_divergence, index} when price makes higher high but MFI makes lower high
  """
  def detect_divergences(candles, mfi_data, lookback \\ 5) do
    result =
      Enum.with_index(candles)
      # Skip first lookback periods
      |> Enum.drop(lookback)
      |> Enum.flat_map(fn {_, index} ->
        if index >= lookback and index < length(mfi_data) do
          # Get data for the current window
          window_candles = Enum.slice(candles, (index - lookback)..index)

          window_mfi =
            Enum.slice(mfi_data, (index - lookback)..index)
            |> Enum.map(& &1.mfi)
            |> Enum.filter(&(!is_nil(&1)))

          # Only proceed if we have enough MFI values
          if length(window_mfi) > 3 do
            # Extract price high/low from candles
            window_highs = Enum.map(window_candles, & &1.high)
            window_lows = Enum.map(window_candles, & &1.low)

            # Check for divergences
            detected_divergences = []

            # Check for bullish divergence (price lower low, MFI higher low)
            current_low = List.last(window_lows)
            min_low = Enum.min(Enum.take(window_lows, length(window_lows) - 1))

            detected_divergences =
              if current_low < min_low and
                   List.last(window_mfi) > Enum.min(Enum.take(window_mfi, length(window_mfi) - 1)) do
                [{:bullish_divergence, index} | detected_divergences]
              else
                detected_divergences
              end

            # Check for bearish divergence (price higher high, MFI lower high)
            current_high = List.last(window_highs)
            max_high = Enum.max(Enum.take(window_highs, length(window_highs) - 1))

            detected_divergences =
              if current_high > max_high and
                   List.last(window_mfi) < Enum.max(Enum.take(window_mfi, length(window_mfi) - 1)) do
                [{:bearish_divergence, index} | detected_divergences]
              else
                detected_divergences
              end

            detected_divergences
          else
            []
          end
        else
          []
        end
      end)

    {:ok, result}
  end

  @doc """
  Generates trading signals based on MFI values.

  ## Parameters
    - mfi_data: List of MFI result maps from calculate/4
    - overbought_threshold: Threshold for overbought condition (default: 80)
    - oversold_threshold: Threshold for oversold condition (default: 20)

  ## Returns
    - {:ok, signals} where signals is a list of trading signals:
      - 1 for buy signal (MFI crosses above oversold threshold from below)
      - -1 for sell signal (MFI crosses below overbought threshold from above)
      - 0 for no signal
  """
  def generate_signals(mfi_data, overbought_threshold \\ 80, oversold_threshold \\ 20) do
    signals =
      mfi_data
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        cond do
          # Check if prev MFI was below oversold and current is above (buy signal)
          !is_nil(prev.mfi) and !is_nil(curr.mfi) and
            prev.mfi < oversold_threshold and curr.mfi >= oversold_threshold ->
            1

          # Check if prev MFI was above overbought and current is below (sell signal)
          !is_nil(prev.mfi) and !is_nil(curr.mfi) and
            prev.mfi > overbought_threshold and curr.mfi <= overbought_threshold ->
            -1

          # No signal
          true ->
            0
        end
      end)
      # Add a 0 for the first period which has no prior data
      |> List.insert_at(0, 0)

    {:ok, signals}
  end
end
