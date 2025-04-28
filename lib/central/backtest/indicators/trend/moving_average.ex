defmodule Central.Backtest.Indicators.Trend.MovingAverage do
  @moduledoc """
  Implements various moving average calculations.
  """

  alias Central.Backtest.Indicators.Calculations.{Math, ListOperations}

  @doc """
  Calculates a Simple Moving Average (SMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to average
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of SMA values aligned with the input candles (first period-1 values are nil)
  """
  def sma(candles, period, price_key \\ :close)
      when is_list(candles) and is_integer(period) and period > 0 do
    candles
    |> ListOperations.extract_key(price_key)
    |> calculate_sma(period, [])
  end

  defp calculate_sma(prices, period, results) when length(prices) < period do
    # Pad with nil for periods with insufficient data
    Enum.reverse(results) ++ List.duplicate(nil, length(prices))
  end

  defp calculate_sma(prices, period, results) do
    {window, _rest} = Enum.split(prices, period)

    # Calculate average for current window
    avg = Math.average(window)

    # Recurse with remaining prices
    calculate_sma(tl(prices), period, [avg | results])
  end

  @doc """
  Calculates an Exponential Moving Average (EMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the EMA
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of EMA values aligned with the input candles (first period-1 values are nil)
  """
  def ema(candles, period, price_key \\ :close)
      when is_list(candles) and is_integer(period) and period > 0 do
    prices = ListOperations.extract_key(candles, price_key)

    # Calculate multiplier: 2 / (period + 1)
    multiplier = Decimal.div(Decimal.new(2), Decimal.add(Decimal.new(period), Decimal.new(1)))

    # Use SMA as first value
    {sma_values, _} =
      prices
      |> Enum.take(period)
      |> calculate_sma(period, [])
      |> List.pop_at(0)

    # Calculate EMA starting with SMA as seed
    prices
    |> Enum.drop(period - 1)
    |> calculate_ema(multiplier, sma_values, [])
    |> then(fn ema_values ->
      # Add nil values at the beginning to align with input
      List.duplicate(nil, period - 1) ++ Enum.reverse(ema_values)
    end)
  end

  defp calculate_ema([], _multiplier, _prev_ema, results), do: results

  defp calculate_ema([price | rest], multiplier, prev_ema, results) do
    # EMA = Price * multiplier + Previous EMA * (1 - multiplier)
    new_ema =
      Decimal.add(
        Decimal.mult(price, multiplier),
        Decimal.mult(prev_ema, Decimal.sub(Decimal.new(1), multiplier))
      )

    calculate_ema(rest, multiplier, new_ema, [new_ema | results])
  end

  @doc """
  Calculates an EMA from a list of values (not candles).

  ## Parameters
    - values: List of numeric values
    - period: Number of periods for the EMA

  ## Returns
    - List of EMA values
  """
  def calculate_ema_from_values(values, period)
      when is_list(values) and is_integer(period) and period > 0 do
    # Use SMA as first value
    first_sma = Enum.take(values, period) |> Math.average()

    # Calculate multiplier
    multiplier = Decimal.div(Decimal.new(2), Decimal.add(Decimal.new(period), Decimal.new(1)))

    # Calculate EMA
    values
    |> Enum.drop(period)
    |> calculate_ema(multiplier, first_sma, [])
    |> Enum.reverse()
  end

  @doc """
  Generic moving average calculation with type selection.

  ## Parameters
    - prices: List of price values
    - period: Number of periods for the moving average
    - type: The type of moving average to calculate (:simple, :weighted, etc.)

  ## Returns
    - {:ok, result} with the list of moving average values
    - {:error, reason} if calculation fails
  """
  def calculate(prices, period, type)
      when is_list(prices) and is_integer(period) and period > 0 do
    result =
      case type do
        :simple ->
          # Calculate simple moving average
          calculate_sma(prices, period, [])

        :weighted ->
          # Calculate weighted moving average
          calculate_wma(prices, period)

        _ ->
          {:error, "Unsupported moving average type: #{type}"}
      end

    case result do
      {:error, _} = error -> error
      values when is_list(values) -> {:ok, values}
    end
  end

  @doc """
  Calculates a Weighted Moving Average (WMA).

  ## Parameters
    - prices: List of price values
    - period: Number of periods for the WMA

  ## Returns
    - List of WMA values
  """
  def calculate_wma(prices, period) when length(prices) < period do
    # Not enough data for calculation
    List.duplicate(nil, length(prices))
  end

  def calculate_wma(prices, period) do
    # Calculate weights: 1, 2, 3, ..., period
    weights = Enum.to_list(1..period)
    weight_sum = Enum.sum(weights)

    prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn window ->
      # Multiply each value by its weight, sum, then divide by weight sum
      window
      |> Enum.zip(weights)
      |> Enum.map(fn {price, weight} -> Decimal.mult(price, Decimal.new(weight)) end)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      |> Decimal.div(Decimal.new(weight_sum))
    end)
    |> then(fn wma_values ->
      # Add nil values at the beginning to align with input
      List.duplicate(nil, period - 1) ++ wma_values
    end)
  end
end
