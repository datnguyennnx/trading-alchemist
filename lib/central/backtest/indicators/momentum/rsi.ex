defmodule Central.Backtest.Indicators.Momentum.Rsi do
  @moduledoc """
  Implements the Relative Strength Index (RSI) calculation.
  """

  alias Central.Backtest.Indicators.Calculations.{Math, ListOperations}

  @doc """
  Calculates the Relative Strength Index (RSI) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the RSI (typically 14)
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of RSI values aligned with the input candles (first period values are nil)
  """
  def rsi(candles, period \\ 14, price_key \\ :close)
      when is_list(candles) and is_integer(period) and period > 0 do
    # Extract prices
    prices = ListOperations.extract_key(candles, price_key)

    # Calculate price changes
    changes = ListOperations.calculate_changes(prices)

    # Separate gains and losses
    {gains, losses} = ListOperations.separate_gains_losses(changes)

    # Calculate initial averages (simple averages for the first period)
    initial_avg_gain = Enum.take(gains, period) |> Math.average()
    initial_avg_loss = Enum.take(losses, period) |> Math.average()

    # Calculate RSI for each point using smoothed averages
    calculate_rsi(
      Enum.drop(gains, period),
      Enum.drop(losses, period),
      initial_avg_gain,
      initial_avg_loss,
      period,
      []
    )
    |> then(fn rsi_values ->
      # Add nil values at the beginning to align with input
      List.duplicate(nil, period) ++ Enum.reverse(rsi_values)
    end)
  end

  defp calculate_rsi([], [], _avg_gain, _avg_loss, _period, results), do: results

  defp calculate_rsi(
         [gain | rest_gains],
         [loss | rest_losses],
         avg_gain,
         avg_loss,
         period,
         results
       ) do
    # Calculate smoothed averages:
    # avgGain = ((previous avgGain) * (period - 1) + currentGain) / period
    # avgLoss = ((previous avgLoss) * (period - 1) + currentLoss) / period
    new_avg_gain =
      Decimal.div(
        Decimal.add(
          Decimal.mult(avg_gain, Decimal.new(period - 1)),
          gain
        ),
        Decimal.new(period)
      )

    new_avg_loss =
      Decimal.div(
        Decimal.add(
          Decimal.mult(avg_loss, Decimal.new(period - 1)),
          loss
        ),
        Decimal.new(period)
      )

    # Calculate RS = avgGain / avgLoss
    rs =
      if Decimal.compare(new_avg_loss, Decimal.new(0)) == :gt do
        Decimal.div(new_avg_gain, new_avg_loss)
      else
        # If no losses, RS is maximal
        Decimal.new(100)
      end

    # Calculate RSI = 100 - (100 / (1 + RS))
    rsi_value =
      Decimal.sub(
        Decimal.new(100),
        Decimal.div(
          Decimal.new(100),
          Decimal.add(Decimal.new(1), rs)
        )
      )

    calculate_rsi(rest_gains, rest_losses, new_avg_gain, new_avg_loss, period, [
      rsi_value | results
    ])
  end
end
