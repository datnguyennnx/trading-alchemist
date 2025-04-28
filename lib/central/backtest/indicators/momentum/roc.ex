defmodule Central.Backtest.Indicators.Momentum.Roc do
  @moduledoc """
  Implementation of the Rate of Change (ROC) indicator.

  The Rate of Change (ROC) is a pure momentum oscillator that measures the percent change in price
  from one period to the next. The ROC calculation compares the current price with the price "n" periods ago.

  ROC = [(Current Price - Price n periods ago) / (Price n periods ago)] * 100
  """

  alias Central.Backtest.Indicators.IndicatorUtils

  @doc """
  Calculates the Rate of Change (ROC) for the given candles, period, and price key.

  This is the main public interface function that matches the facade in indicators.ex.
  """
  @spec roc(list(), integer(), atom()) :: list()
  def roc(candles, period \\ 14, price_key \\ :close) do
    prices = IndicatorUtils.extract_price(candles, price_key)
    calculate_prices(prices, period)
  end

  @doc """
  Calculates the Rate of Change (ROC) for OHLCV data.
  Uses the close price by default.
  """
  @spec calculate(list(), keyword()) :: list()
  def calculate(data, options) when is_list(options) do
    period = Keyword.get(options, :period, 14)
    price_type = Keyword.get(options, :price_type, :close)

    prices = IndicatorUtils.extract_price(data, price_type)
    calculate_prices(prices, period)
  end

  @doc """
  Calculates the Rate of Change (ROC) for the given price data and period.

  ROC measures the percentage change in price between the current price and the price n periods ago.

  Formula: ROC = ((Current Price - Price n periods ago) / Price n periods ago) * 100
  """
  @spec calculate_prices(list(), integer()) :: list()
  def calculate_prices(prices, period)
      when is_list(prices) and is_integer(period) and period > 0 do
    prices
    |> Enum.with_index()
    |> Enum.map(fn {_price, idx} ->
      calculate_roc(prices, idx, period)
    end)
    |> IndicatorUtils.normalize_output()
  end

  defp calculate_roc(prices, current_idx, period) do
    if current_idx >= period do
      current_price = Enum.at(prices, current_idx)
      previous_price = Enum.at(prices, current_idx - period)

      if Decimal.equal?(previous_price, Decimal.new(0)) do
        Decimal.new(0)
      else
        Decimal.mult(
          Decimal.div(
            Decimal.sub(current_price, previous_price),
            previous_price
          ),
          Decimal.new(100)
        )
      end
    else
      nil
    end
  end

  @doc """
  Calculates the Rate of Change with timestamps.

  ## Parameters
    - candles: List of candle data
    - period: Number of periods to use for calculation
    - price_key: Key to use for price data (:close, :open, :high, :low)

  ## Returns
    - List of maps containing :timestamp and :roc values
  """
  def roc_with_timestamp(candles, period \\ 14, price_key \\ :close) do
    roc_values = calculate(candles, period: period, price_type: price_key)
    IndicatorUtils.with_timestamp(candles, roc_values, :roc)
  end

  @doc """
  Convenience function for calculating ROC with default parameters.
  Matches the standard signature pattern used across indicators.

  ## Parameters
    - candles: List of candle data
    - period: Number of periods for calculation (default: 14)
    - price_key: Key to use for price data (default: :close)

  ## Returns
    - {:ok, roc_values} where roc_values is a list of ROC values
  """
  def roc_indicator(candles, period \\ 14, price_key \\ :close) do
    result = calculate(candles, period: period, price_type: price_key)
    {:ok, result}
  end

  @doc """
  Analyzes ROC data for potential trading signals.

  ## Parameters
    - roc_data: List of ROC values or maps with :roc key

  ## Returns
    - List of maps with added analysis data
  """
  def analyze(roc_data) do
    # Preprocess input to handle both raw ROC values and maps with ROC values
    processed_data =
      Enum.map(roc_data, fn
        %{roc: value} = entry -> {entry, value}
        value when is_number(value) or is_struct(value, Decimal) -> {%{roc: value}, value}
        value -> {%{roc: value}, value}
      end)

    # Set thresholds for overbought/oversold conditions
    overbought_threshold = Decimal.new(10)
    oversold_threshold = Decimal.new(-10)

    # Analyze trend, crossovers, and divergences
    processed_data
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{_prev_entry, prev_roc}, {curr_entry, curr_roc}] ->
      # Skip analysis if either value is nil
      if is_nil(prev_roc) or is_nil(curr_roc) do
        Map.put(curr_entry, :signal, :insufficient_data)
      else
        # Determine trend direction
        trend =
          cond do
            Decimal.gt?(curr_roc, Decimal.new(0)) and Decimal.gt?(curr_roc, prev_roc) ->
              :bullish

            Decimal.gt?(curr_roc, Decimal.new(0)) and Decimal.lt?(curr_roc, prev_roc) ->
              :weakening_bullish

            Decimal.lt?(curr_roc, Decimal.new(0)) and Decimal.lt?(curr_roc, prev_roc) ->
              :bearish

            Decimal.lt?(curr_roc, Decimal.new(0)) and Decimal.gt?(curr_roc, prev_roc) ->
              :weakening_bearish

            Decimal.equal?(curr_roc, prev_roc) ->
              :neutral

            true ->
              :neutral
          end

        # Determine if price crossed zero line
        zero_cross =
          cond do
            Decimal.lt?(prev_roc, Decimal.new(0)) and Decimal.gt?(curr_roc, Decimal.new(0)) ->
              :bullish_cross

            Decimal.gt?(prev_roc, Decimal.new(0)) and Decimal.lt?(curr_roc, Decimal.new(0)) ->
              :bearish_cross

            true ->
              :none
          end

        # Determine extreme conditions
        condition =
          cond do
            Decimal.gte?(curr_roc, overbought_threshold) -> :overbought
            Decimal.lte?(curr_roc, oversold_threshold) -> :oversold
            true -> :normal
          end

        # Generate trading signal
        signal =
          cond do
            zero_cross == :bullish_cross -> :buy
            zero_cross == :bearish_cross -> :sell
            condition == :oversold and trend == :weakening_bearish -> :consider_buy
            condition == :overbought and trend == :weakening_bullish -> :consider_sell
            true -> :hold
          end

        curr_entry
        |> Map.put(:trend, trend)
        |> Map.put(:zero_cross, zero_cross)
        |> Map.put(:condition, condition)
        |> Map.put(:signal, signal)
      end
    end)
    |> then(fn analyzed ->
      # Add nil entry at beginning to match original data length
      [%{signal: :insufficient_data} | analyzed]
    end)
  end
end
