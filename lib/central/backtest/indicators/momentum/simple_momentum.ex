defmodule Central.Backtest.Indicators.Momentum.SimpleMomentum do
  @moduledoc """
  Implements the Simple Momentum indicator.

  Simple Momentum measures the absolute price change over a specified period.
  It's one of the most basic momentum indicators and forms the foundation for
  many other more complex indicators.

  The calculation involves:
  1. Calculate the price difference between current price and price n periods ago
  2. The result can be expressed as an absolute difference or percentage change

  ## Parameters

  - prices: List of price values (typically closing prices)
  - period: Number of periods for momentum calculation (default: 10)
  - return_percentage: Whether to return percentage change (default: false)

  ## Returns

  A tuple containing:
  - {:ok, momentum_values} on success
  - {:error, reason} on failure
  """

  @doc """
  Calculates Simple Momentum.
  """
  def calculate(prices, period \\ 10, return_percentage \\ false) do
    with true <- validate_inputs(prices, period) do
      momentum = calculate_momentum(prices, period, return_percentage)
      {:ok, momentum}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates Simple Momentum for candles with specific parameters.
  This function matches the signature in indicators.ex.
  """
  def calculate(candles, period, return_percentage, price_key)
      when is_list(candles) and is_atom(price_key) do
    prices = Enum.map(candles, &Map.get(&1, price_key))
    calculate(prices, period, return_percentage)
  end

  @doc """
  Calculates Simple Momentum for OHLC candles with specified price type.

  ## Parameters
    - candles: List of candle maps with price data
    - period: Number of periods for momentum calculation (default: 10)
    - return_percentage: Whether to return percentage change (default: false)
    - price_type: Price type to use (:close, :open, :high, :low)

  ## Returns
    - {:ok, momentum_values} on success
    - {:error, reason} on failure
  """
  def calculate_from_candles(
        candles,
        period \\ 10,
        return_percentage \\ false,
        price_type \\ :close
      )
      when is_list(candles) and is_atom(price_type) do
    prices = Enum.map(candles, &Map.get(&1, price_type))
    calculate(prices, period, return_percentage)
  end

  defp validate_inputs(prices, period) do
    cond do
      not is_list(prices) ->
        {:error, "Prices must be a list"}

      period <= 0 ->
        {:error, "Period must be greater than 0"}

      length(prices) < period ->
        {:error, "Not enough data points for the given period"}

      true ->
        true
    end
  end

  defp calculate_momentum(prices, period, return_percentage) do
    prices
    |> Enum.chunk_every(period + 1, 1, :discard)
    |> Enum.map(fn chunk ->
      current = List.last(chunk)
      previous = List.first(chunk)

      if return_percentage do
        if previous == 0, do: 0, else: (current - previous) / previous * 100
      else
        current - previous
      end
    end)
    |> pad_with_zeros(length(prices), period)
  end

  defp pad_with_zeros(values, original_length, _period) do
    padding_length = original_length - length(values)
    List.duplicate(0, padding_length) ++ values
  end

  @doc """
  Generates trading signals based on Simple Momentum.

  Returns:
  - 1 for buy signal (momentum crosses above zero)
  - -1 for sell signal (momentum crosses below zero)
  - 0 for no signal
  """
  def generate_signals(momentum) do
    momentum
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      cond do
        prev <= 0 and curr > 0 -> 1
        prev >= 0 and curr < 0 -> -1
        true -> 0
      end
    end)
    |> List.insert_at(0, 0)
  end

  @doc """
  Analyzes momentum strength by classifying values into categories.

  Returns a list of atoms representing the strength of each momentum value:
  - :strong_positive - Strong positive momentum
  - :positive - Positive momentum
  - :neutral - Minimal momentum
  - :negative - Negative momentum
  - :strong_negative - Strong negative momentum
  """
  def classify_strength(momentum, strong_threshold \\ 5.0) do
    Enum.map(momentum, fn value ->
      cond do
        value > strong_threshold -> :strong_positive
        value > 0 -> :positive
        value == 0 -> :neutral
        value > -strong_threshold -> :negative
        true -> :strong_negative
      end
    end)
  end

  @doc """
  Calculates acceleration of momentum by taking the rate of change of momentum itself.

  Returns a list of acceleration values.
  """
  def calculate_acceleration(momentum, period \\ 3) do
    momentum
    |> Enum.chunk_every(period + 1, 1, :discard)
    |> Enum.map(fn chunk ->
      current = List.last(chunk)
      previous = List.first(chunk)
      current - previous
    end)
    |> pad_with_zeros(length(momentum), period)
  end

  @doc """
  Finds divergences between price and momentum.

  Returns a list of divergence events:
  - {:bullish_divergence, index} when price makes lower low but momentum makes higher low
  - {:bearish_divergence, index} when price makes higher high but momentum makes lower high
  """
  def find_divergences(prices, momentum, lookback \\ 5) do
    Enum.zip(prices, momentum)
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.flat_map(fn {window, index} ->
      find_divergences_in_window(window, index)
    end)
  end

  defp find_divergences_in_window(window, index) do
    {prices, momentum_values} = Enum.unzip(window)

    divergences = []

    # Check for bullish divergence
    divergences =
      if Enum.min(prices) == List.last(prices) and
           Enum.min(momentum_values) != List.last(momentum_values) and
           Enum.min(momentum_values) < List.last(momentum_values) do
        [{:bullish_divergence, index} | divergences]
      else
        divergences
      end

    # Check for bearish divergence
    divergences =
      if Enum.max(prices) == List.last(prices) and
           Enum.max(momentum_values) != List.last(momentum_values) and
           Enum.max(momentum_values) > List.last(momentum_values) do
        [{:bearish_divergence, index} | divergences]
      else
        divergences
      end

    divergences
  end
end
