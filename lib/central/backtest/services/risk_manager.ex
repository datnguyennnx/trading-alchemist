defmodule Central.Backtest.Services.RiskManager do
  @moduledoc """
  Service for managing risk in trading strategies.
  Calculates position sizes, stop-loss levels, and risk metrics.
  """

  require Logger
  alias Central.Backtest.Schemas.Backtest
  alias Central.Backtest.Services.MarketDataHandler
  alias Central.Utils.TradeAdapter
  alias Central.Repo

  @doc """
  Updates risk metrics for a backtest based on completed trades.
  Calculates metrics like max drawdown, risk-reward ratio, and more.
  """
  def update_risk_metrics(backtest_id) do
    # Get the backtest with trades
    backtest = Repo.get!(Backtest, backtest_id) |> Repo.preload(:trades)

    # Skip if not completed or no trades
    if backtest.status != :completed or Enum.empty?(backtest.trades) do
      Logger.info("No risk metrics updated for backtest #{backtest_id}: status=#{backtest.status}, trades=#{length(backtest.trades)}")
      :ok
    else
      # Make trades backward compatible with field names
      backtest = %{backtest | trades: TradeAdapter.adapt_trades(backtest.trades)}

      # Calculate risk metrics
      metrics = calculate_risk_metrics(backtest)

      # Update backtest with risk metrics
      update_backtest_risk_metrics(backtest, metrics)

      {:ok, metrics}
    end
  end

  @doc """
  Calculates optimal position size based on account balance and risk parameters.

  ## Parameters
    - balance: Current account balance
    - backtest: Backtest struct containing risk parameters

  ## Returns
    - position_size as a float
  """
  def calculate_position_size(balance, backtest) do
    # Get position size percentage from backtest params or default to 2%
    position_size_pct = case get_position_size(backtest) do
      nil -> 0.02  # Default to 2%
      size when is_number(size) -> size / 100.0
      size ->
        case Decimal.cast(size) do
          {:ok, decimal} -> Decimal.to_float(decimal) / 100.0
          :error -> 0.02
        end
    end

    # Calculate position size
    balance * position_size_pct
  end

  @doc """
  Extract position size parameter from backtest configuration.

  ## Parameters
    - backtest: Backtest struct containing configuration

  ## Returns
    - position_size as a float or nil if not found
  """
  def get_position_size(backtest) do
    cond do
      # Check if position_size is available in metadata
      is_map(backtest.metadata) && Map.has_key?(backtest.metadata, "position_size") ->
        MarketDataHandler.parse_decimal_or_float(backtest.metadata["position_size"])

      # Fall back to risk_per_trade from strategy config
      backtest.strategy && is_map(backtest.strategy.config) && Map.has_key?(backtest.strategy.config, "risk_per_trade") ->
        MarketDataHandler.parse_decimal_or_float(backtest.strategy.config["risk_per_trade"])

      # Otherwise use default
      true -> 2.0
    end
  end

  @doc """
  Calculates maximum drawdown from a series of equity points.

  ## Parameters
    - equity_curve: List of maps with :timestamp and :equity keys

  ## Returns
    - {max_drawdown, max_drawdown_percentage, start_time, end_time}
  """
  def calculate_max_drawdown(equity_curve) do
    # Default return if insufficient data
    if length(equity_curve) < 2 do
      {Decimal.new(0), Decimal.new(0), nil, nil}
    else
      # Sort by timestamp to ensure proper order
      sorted_curve = Enum.sort_by(equity_curve, & &1.timestamp, DateTime)

      # Calculate running peak and drawdown
      {_, _, max_dd, max_dd_pct, start_time, end_time} =
        Enum.reduce(sorted_curve, {nil, nil, Decimal.new(0), Decimal.new(0), nil, nil},
          fn %{timestamp: time, equity: equity}, {prev_peak, prev_time, max_dd, max_dd_pct, dd_start, dd_end} = acc ->
            # Skip first point (no previous to compare with)
            if is_nil(prev_peak) do
              {equity, time, max_dd, max_dd_pct, nil, nil}
            else
              # If new equity is higher than peak, update peak
              if Decimal.compare(equity, prev_peak) == :gt do
                {equity, time, max_dd, max_dd_pct, dd_start, dd_end}
              else
                # Calculate current drawdown
                curr_dd = Decimal.sub(prev_peak, equity)
                curr_dd_pct = Decimal.div(curr_dd, prev_peak)

                # Check if this is a new maximum drawdown
                if Decimal.compare(curr_dd, max_dd) == :gt do
                  {prev_peak, prev_time, curr_dd, curr_dd_pct, prev_time, time}
                else
                  {prev_peak, prev_time, max_dd, max_dd_pct, dd_start, dd_end}
                end
              end
            end
          end)

      # Convert percentage to actual percentage value (multiply by 100)
      max_dd_pct_display = Decimal.mult(max_dd_pct, Decimal.new(100))

      {max_dd, max_dd_pct_display, start_time, end_time}
    end
  end

  # Calculate risk metrics for a backtest
  defp calculate_risk_metrics(backtest) do
    trades = backtest.trades

    # Calculate win/loss ratio
    winning_trades = Enum.filter(trades, fn t -> t.pnl > 0 end)
    losing_trades = Enum.filter(trades, fn t -> t.pnl < 0 end)

    win_loss_ratio =
      if length(losing_trades) > 0 do
        length(winning_trades) / length(losing_trades)
      else
        length(winning_trades)
      end

    # Calculate average risk-reward ratio
    avg_win =
      if length(winning_trades) > 0 do
        winning_trades
        |> Enum.map(fn t -> t.pnl end)
        |> Enum.sum()
        |> Kernel./(length(winning_trades))
      else
        0
      end

    avg_loss =
      if length(losing_trades) > 0 do
        losing_trades
        |> Enum.map(fn t -> abs(t.pnl) end)
        |> Enum.sum()
        |> Kernel./(length(losing_trades))
      else
        1  # Avoid division by zero
      end

    risk_reward_ratio =
      if avg_loss > 0 do
        avg_win / avg_loss
      else
        0
      end

    # Calculate expectancy
    win_rate = length(winning_trades) / max(length(trades), 1)
    loss_rate = length(losing_trades) / max(length(trades), 1)
    expectancy = (win_rate * avg_win) - (loss_rate * avg_loss)

    # Calculate maximum consecutive losses
    consecutive_losses = calculate_consecutive_losses(trades)

    # Return risk metrics
    %{
      win_loss_ratio: win_loss_ratio,
      risk_reward_ratio: risk_reward_ratio,
      expectancy: expectancy,
      max_consecutive_losses: consecutive_losses,
      avg_win: avg_win,
      avg_loss: avg_loss
    }
  end

  # Calculate maximum consecutive losses
  defp calculate_consecutive_losses(trades) do
    # Sort trades by time
    sorted_trades = Enum.sort_by(trades, & &1.entry_time)

    # Track consecutive losses
    {_, max_consecutive} =
      Enum.reduce(sorted_trades, {0, 0}, fn trade, {current, max} ->
        if trade.pnl < 0 do
          current = current + 1
          {current, max(current, max)}
        else
          {0, max}
        end
      end)

    max_consecutive
  end

  # Update backtest with risk metrics
  defp update_backtest_risk_metrics(backtest, metrics) do
    # Update backtest metadata with risk metrics
    metadata = Map.merge(backtest.metadata || %{}, %{
      "risk_metrics" => %{
        "win_loss_ratio" => metrics.win_loss_ratio,
        "risk_reward_ratio" => metrics.risk_reward_ratio,
        "expectancy" => metrics.expectancy,
        "max_consecutive_losses" => metrics.max_consecutive_losses
      }
    })

    # Update backtest
    backtest
    |> Ecto.Changeset.change(%{metadata: metadata})
    |> Repo.update!()
  end
end
