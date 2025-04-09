defmodule Central.Backtest.Services.TradeManager do
  @moduledoc """
  Manages trade operations for backtesting, including opening and closing positions,
  calculating profit/loss, and tracking trade statistics.
  """

  require Logger
  alias Central.Backtest.Services.MarketDataHandler
  alias Central.Utils.DatetimeUtils

  @doc """
  Closes an open position and records the trade.

  ## Parameters
    - state: Current backtest state containing position and balance
    - exit_price: Price at which to close the position
    - reason: Reason for closing the position
    - backtest: Backtest struct with configuration parameters

  ## Returns
    - Updated state with position closed and trade recorded
  """
  def close_position(state, exit_price, reason, backtest) do
    position = state.position

    # Log for debugging
    Logger.debug("Closing position: entry_price=#{inspect(position.entry_price)}, exit_price=#{inspect(exit_price)}, size=#{inspect(position.size)}")

    # Calculate profit/loss
    profit_loss = calculate_profit_loss(position, exit_price)

    Logger.debug("Calculated profit_loss: #{inspect(profit_loss)}")

    # Create trade record - use proper UTC DateTime
    trade = %{
      entry_price: position.entry_price,
      entry_time: position.entry_time,
      exit_price: exit_price,
      exit_time: DatetimeUtils.utc_now_sec(),
      size: position.size,
      direction: position.direction,
      pnl: profit_loss,
      reason: reason
    }

    # Update balance - ensure everything is properly converted to floats
    balance = MarketDataHandler.parse_decimal_or_float(state.balance)
    new_balance = balance + profit_loss

    Logger.debug("Updated balance: #{inspect(balance)} + #{inspect(profit_loss)} = #{inspect(new_balance)}")

    # Return updated state
    %{
      state |
      balance: new_balance,
      position: nil,
      trades: [trade | state.trades]
    }
  end

  @doc """
  Calculates profit or loss for a position.

  ## Parameters
    - position: The position struct with entry price, size, and direction
    - exit_price: Price at which the position will be closed

  ## Returns
    - Profit/loss amount as a float
  """
  def calculate_profit_loss(position, exit_price) do
    # Ensure values are floats
    entry_price = MarketDataHandler.parse_decimal_or_float(position.entry_price)
    exit_price_float = MarketDataHandler.parse_decimal_or_float(exit_price)
    size = MarketDataHandler.parse_decimal_or_float(position.size)

    # Log the values for debugging
    Logger.debug("Calculating profit/loss: entry_price=#{entry_price}, exit_price=#{exit_price_float}, size=#{size}")

    result = case position.direction do
      :long ->
        size * (exit_price_float - entry_price) / entry_price
      :short ->
        size * (entry_price - exit_price_float) / entry_price
    end

    Logger.debug("Profit/loss result: #{result}")
    result
  end
end
