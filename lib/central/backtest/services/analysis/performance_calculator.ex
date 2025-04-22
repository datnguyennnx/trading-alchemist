defmodule Central.Backtest.Services.Analysis.PerformanceCalculator do
  @moduledoc """
  Service for calculating performance metrics for backtests.
  Includes profit/loss statistics, drawdown metrics, and other trading performance indicators.
  """

  require Logger
  alias Central.Backtest.Schemas.Backtest
  alias Central.Backtest.Services.Risk.RiskManager
  alias Central.Backtest.Utils.TradeAdapter
  alias Central.Repo

  @doc """
  Generates a performance summary for a completed backtest.
  Calculates key metrics like win rate, profit factor, and drawdown.
  """
  def generate_performance_summary(backtest_id) do
    # Get the backtest with trades
    backtest = Repo.get!(Backtest, backtest_id) |> Repo.preload(:trades)

    # Skip if no trades or not completed
    if backtest.status != :completed or Enum.empty?(backtest.trades) do
      Logger.info(
        "No performance summary generated for backtest #{backtest_id}: status=#{backtest.status}, trades=#{length(backtest.trades)}"
      )

      :ok
    else
      # Make trades backward compatible with field names
      backtest = %{backtest | trades: TradeAdapter.adapt_trades(backtest.trades)}

      # Calculate performance metrics
      metrics = calculate_metrics(backtest)

      # Save performance summary
      save_performance_summary(backtest, metrics)

      # Return the metrics
      {:ok, metrics}
    end
  end

  # Calculate key performance metrics
  defp calculate_metrics(backtest) do
    trades = backtest.trades

    # Basic trade stats
    total_trades = length(trades)
    winning_trades = Enum.count(trades, fn t -> t.pnl > 0 end)
    losing_trades = Enum.count(trades, fn t -> t.pnl < 0 end)
    break_even_trades = total_trades - winning_trades - losing_trades

    # Profit metrics
    total_profit =
      Enum.reduce(trades, 0, fn t, acc ->
        if t.pnl > 0, do: acc + t.pnl, else: acc
      end)

    total_loss =
      Enum.reduce(trades, 0, fn t, acc ->
        if t.pnl < 0, do: acc + abs(t.pnl), else: acc
      end)

    net_profit = total_profit - total_loss
    profit_factor = if total_loss > 0, do: total_profit / total_loss, else: total_profit

    # Win rate
    win_rate = if total_trades > 0, do: winning_trades / total_trades * 100, else: 0

    # Average trade
    avg_profit = if winning_trades > 0, do: total_profit / winning_trades, else: 0
    avg_loss = if losing_trades > 0, do: total_loss / losing_trades, else: 0
    avg_trade = if total_trades > 0, do: net_profit / total_trades, else: 0

    # Drawdown analysis
    {max_drawdown, max_drawdown_pct} = calculate_drawdown(backtest)

    # Return percentage return
    initial_balance = backtest.initial_balance || 10000.0
    final_balance = backtest.final_balance || initial_balance
    percent_return = (final_balance - initial_balance) / initial_balance * 100

    # Return metrics
    %{
      total_trades: total_trades,
      winning_trades: winning_trades,
      losing_trades: losing_trades,
      break_even_trades: break_even_trades,
      win_rate: win_rate,
      total_profit: total_profit,
      total_loss: total_loss,
      net_profit: net_profit,
      profit_factor: profit_factor,
      avg_profit: avg_profit,
      avg_loss: avg_loss,
      avg_trade: avg_trade,
      max_drawdown: max_drawdown,
      max_drawdown_pct: max_drawdown_pct,
      initial_balance: initial_balance,
      final_balance: final_balance,
      percent_return: percent_return
    }
  end

  # Calculate drawdown metrics
  defp calculate_drawdown(backtest) do
    # For simplicity, we'll estimate drawdown from trade sequence
    trades = backtest.trades
    initial_balance = backtest.initial_balance || 10000.0

    # Sort trades by entry time
    sorted_trades = Enum.sort_by(trades, & &1.entry_time)

    # Track equity curve and drawdown
    {_, _, max_drawdown, max_drawdown_pct} =
      Enum.reduce(sorted_trades, {initial_balance, initial_balance, 0, 0}, fn trade,
                                                                              {equity, peak,
                                                                               max_dd,
                                                                               max_dd_pct} ->
        # Update equity
        new_equity = equity + trade.pnl

        # Update peak if new equity is higher
        new_peak = max(new_equity, peak)

        # Calculate current drawdown
        current_dd = new_peak - new_equity
        current_dd_pct = if new_peak > 0, do: current_dd / new_peak * 100, else: 0

        # Update max drawdown if current is higher
        new_max_dd = max(current_dd, max_dd)
        new_max_dd_pct = max(current_dd_pct, max_dd_pct)

        {new_equity, new_peak, new_max_dd, new_max_dd_pct}
      end)

    {max_drawdown, max_drawdown_pct}
  end

  # Save performance summary to database
  defp save_performance_summary(backtest, metrics) do
    # Create a performance summary record
    performance_summary = %{
      backtest_id: backtest.id,
      total_trades: metrics.total_trades,
      winning_trades: metrics.winning_trades,
      losing_trades: metrics.losing_trades,
      win_rate: metrics.win_rate,
      profit_factor: metrics.profit_factor,
      max_drawdown: metrics.max_drawdown,
      max_drawdown_pct: metrics.max_drawdown_pct,
      net_profit: metrics.net_profit,
      percent_return: metrics.percent_return,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # Update the backtest metadata with summary info
    metadata =
      Map.merge(backtest.metadata || %{}, %{
        "performance_summary" => %{
          "win_rate" => metrics.win_rate,
          "profit_factor" => metrics.profit_factor,
          "max_drawdown_pct" => metrics.max_drawdown_pct,
          "percent_return" => metrics.percent_return
        }
      })

    # Save changes
    Repo.transaction(fn ->
      # Insert performance summary
      Repo.insert_all("backtest_performance_summaries", [performance_summary])

      # Update backtest metadata
      backtest
      |> Ecto.Changeset.change(%{metadata: metadata})
      |> Repo.update!()
    end)
  end

  @doc """
  Calculates performance metrics from a list of trades and backtest data.

  ## Parameters
    - trades: List of Trade structs
    - backtest: Backtest struct

  ## Returns
    - Map of performance metrics
  """
  def calculate_performance_metrics(trades, backtest) do
    # Filter to completed trades only
    completed_trades = Enum.filter(trades, &(&1.exit_time != nil && &1.pnl != nil))

    # Skip calculation if no trades
    if Enum.empty?(completed_trades) do
      %{
        total_trades: 0,
        winning_trades: 0,
        losing_trades: 0,
        win_rate: Decimal.new(0),
        profit_factor: Decimal.new(0),
        max_drawdown: Decimal.new(0),
        max_drawdown_percentage: Decimal.new(0),
        sharpe_ratio: Decimal.new(0),
        sortino_ratio: Decimal.new(0),
        total_pnl: Decimal.new(0),
        total_pnl_percentage: Decimal.new(0),
        average_win: Decimal.new(0),
        average_loss: Decimal.new(0),
        largest_win: Decimal.new(0),
        largest_loss: Decimal.new(0),
        metrics: %{}
      }
    else
      # Separate winning and losing trades
      {winning_trades, losing_trades} =
        Enum.split_with(completed_trades, fn trade ->
          Decimal.compare(trade.pnl, Decimal.new(0)) == :gt
        end)

      # Calculate total PnL
      total_pnl = calculate_total_pnl(completed_trades)

      # Calculate win rate
      total_trades = length(completed_trades)
      winning_count = length(winning_trades)
      losing_count = length(losing_trades)
      win_rate = Decimal.div(Decimal.new(winning_count), Decimal.new(total_trades))

      # Calculate profit factor
      total_gains = calculate_total_pnl(winning_trades)
      total_losses = calculate_total_pnl(losing_trades) |> Decimal.abs()

      profit_factor =
        if Decimal.compare(total_losses, Decimal.new(0)) == :gt do
          Decimal.div(total_gains, total_losses)
        else
          # Avoid division by zero
          Decimal.new("999.99")
        end

      # Calculate total PnL percentage
      total_pnl_percentage = Decimal.div(total_pnl, backtest.initial_balance)

      # Calculate average win/loss
      average_win =
        if winning_count > 0 do
          Decimal.div(total_gains, Decimal.new(winning_count))
        else
          Decimal.new(0)
        end

      average_loss =
        if losing_count > 0 do
          Decimal.div(total_losses, Decimal.new(losing_count))
        else
          Decimal.new(0)
        end

      # Find largest win/loss
      largest_win =
        winning_trades
        |> Enum.map(& &1.pnl)
        |> Enum.max(fn -> Decimal.new(0) end)

      largest_loss =
        losing_trades
        |> Enum.map(& &1.pnl)
        |> Enum.min(fn -> Decimal.new(0) end)

      # Calculate equity curve and drawdown
      equity_curve = calculate_equity_curve(backtest.initial_balance, completed_trades)

      {max_drawdown, max_drawdown_percentage, _, _} =
        RiskManager.calculate_max_drawdown(equity_curve)

      # Calculate Sharpe and Sortino ratios
      {sharpe_ratio, sortino_ratio} =
        calculate_risk_adjusted_returns(completed_trades, backtest.initial_balance)

      # Calculate additional metrics
      additional_metrics = %{
        "avg_trade_duration" => calculate_avg_trade_duration(completed_trades),
        "trades_per_day" => calculate_trades_per_day(completed_trades, backtest),
        "expectancy" => calculate_expectancy(win_rate, average_win, average_loss),
        "max_consecutive_wins" => calculate_max_consecutive(completed_trades, :win),
        "max_consecutive_losses" => calculate_max_consecutive(completed_trades, :loss)
      }

      # Return the performance metrics
      %{
        total_trades: total_trades,
        winning_trades: winning_count,
        losing_trades: losing_count,
        win_rate: win_rate,
        profit_factor: profit_factor,
        max_drawdown: max_drawdown,
        max_drawdown_percentage: max_drawdown_percentage,
        sharpe_ratio: sharpe_ratio,
        sortino_ratio: sortino_ratio,
        total_pnl: total_pnl,
        total_pnl_percentage: total_pnl_percentage,
        average_win: average_win,
        average_loss: average_loss,
        largest_win: largest_win,
        largest_loss: largest_loss,
        metrics: additional_metrics
      }
    end
  end

  # Calculates total PnL from a list of trades.
  defp calculate_total_pnl(trades) do
    Enum.reduce(trades, Decimal.new(0), fn trade, acc ->
      Decimal.add(acc, trade.pnl || Decimal.new(0))
    end)
  end

  # Calculates an equity curve from a list of trades.
  # Returns a list of maps with timestamp and equity value.
  defp calculate_equity_curve(initial_balance, trades) do
    # Sort trades by exit time
    sorted_trades = Enum.sort_by(trades, & &1.exit_time, DateTime)

    # Calculate running equity curve
    {curve, _} =
      Enum.reduce(sorted_trades, {[], initial_balance}, fn trade, {points, balance} ->
        new_balance = Decimal.add(balance, trade.pnl)

        point = %{
          timestamp: trade.exit_time,
          equity: new_balance
        }

        {[point | points], new_balance}
      end)

    # Add initial balance point
    first_trade = List.first(sorted_trades)

    if first_trade do
      initial_point = %{
        timestamp: first_trade.entry_time,
        equity: initial_balance
      }

      [initial_point | curve]
    else
      curve
    end
  end

  # Calculates risk-adjusted return metrics (Sharpe and Sortino ratios).
  defp calculate_risk_adjusted_returns(trades, initial_balance) do
    # Calculate daily returns
    daily_returns = calculate_daily_returns(trades, initial_balance)

    if Enum.empty?(daily_returns) do
      {Decimal.new(0), Decimal.new(0)}
    else
      # Calculate average return
      avg_return = Enum.sum(daily_returns) / length(daily_returns)

      # Calculate standard deviation of returns
      std_dev = calculate_standard_deviation(daily_returns, avg_return)

      # Calculate downside deviation (for Sortino)
      negative_returns = Enum.filter(daily_returns, fn r -> r < 0 end)

      downside_dev =
        if Enum.empty?(negative_returns) do
          # No negative returns
          # To avoid division by zero
          1.0
        else
          # Calculate downside deviation
          calculate_standard_deviation(negative_returns, 0)
        end

      # Risk-free rate (assume 0% for simplicity)
      risk_free_rate = 0

      # Calculate Sharpe ratio: (avg_return - risk_free_rate) / std_dev
      sharpe =
        if std_dev > 0 do
          (avg_return - risk_free_rate) / std_dev
        else
          0
        end

      # Calculate Sortino ratio: (avg_return - risk_free_rate) / downside_dev
      sortino =
        if downside_dev > 0 do
          (avg_return - risk_free_rate) / downside_dev
        else
          0
        end

      # Convert to Decimal
      {Decimal.from_float(sharpe), Decimal.from_float(sortino)}
    end
  end

  # Calculates daily returns from a list of trades.
  defp calculate_daily_returns(trades, initial_balance) do
    # Group trades by exit date
    trades_by_day =
      Enum.group_by(trades, fn trade ->
        DateTime.to_date(trade.exit_time)
      end)

    # Calculate daily PnL
    daily_pnl =
      Enum.map(trades_by_day, fn {_date, day_trades} ->
        Enum.reduce(day_trades, Decimal.new(0), fn trade, acc ->
          Decimal.add(acc, trade.pnl)
        end)
      end)

    # Convert to daily returns (percentage)
    Enum.map(daily_pnl, fn pnl ->
      Decimal.to_float(Decimal.div(pnl, initial_balance))
    end)
  end

  # Calculate standard deviation of a list of values.
  defp calculate_standard_deviation(values, mean) do
    # Sum of squared differences
    sum_squared_diff =
      Enum.reduce(values, 0, fn value, acc ->
        diff = value - mean
        acc + diff * diff
      end)

    # Variance is average of squared differences
    variance = sum_squared_diff / length(values)

    # Standard deviation is square root of variance
    :math.sqrt(variance)
  end

  # Calculates average trade duration in minutes.
  defp calculate_avg_trade_duration(trades) do
    if Enum.empty?(trades) do
      Decimal.new(0)
    else
      # Calculate duration of each trade in minutes
      durations =
        Enum.map(trades, fn trade ->
          DateTime.diff(trade.exit_time, trade.entry_time, :second) / 60
        end)

      # Calculate average
      avg_duration = Enum.sum(durations) / length(durations)

      Decimal.from_float(avg_duration)
    end
  end

  # Calculates the average number of trades per day.
  defp calculate_trades_per_day(trades, backtest) do
    if Enum.empty?(trades) do
      Decimal.new(0)
    else
      # Calculate backtest duration in days
      days = DateTime.diff(backtest.end_time, backtest.start_time, :second) / (60 * 60 * 24)

      # Handle very short backtests
      days = max(days, 1)

      # Calculate trades per day
      trades_per_day = length(trades) / days

      Decimal.from_float(trades_per_day)
    end
  end

  # Calculates expectancy: (Win Rate * Average Win) - ((1 - Win Rate) * Average Loss).
  defp calculate_expectancy(win_rate, average_win, average_loss) do
    # Convert to floats for calculation
    win_rate_float = Decimal.to_float(win_rate)
    avg_win_float = Decimal.to_float(average_win)
    avg_loss_float = Decimal.to_float(Decimal.abs(average_loss))

    # Calculate expectancy
    expectancy = win_rate_float * avg_win_float - (1 - win_rate_float) * avg_loss_float

    Decimal.from_float(expectancy)
  end

  # Calculates the maximum consecutive wins or losses.
  defp calculate_max_consecutive(trades, type) do
    # Sort trades by exit time
    sorted_trades = Enum.sort_by(trades, & &1.exit_time, DateTime)

    # Map trades to win/loss sequence
    sequence =
      Enum.map(sorted_trades, fn trade ->
        if Decimal.compare(trade.pnl, Decimal.new(0)) == :gt do
          :win
        else
          :loss
        end
      end)

    # Find max consecutive of specified type
    {max_count, _} =
      Enum.reduce(sequence, {0, 0}, fn result, {max, current} ->
        if result == type do
          new_current = current + 1
          {max(max, new_current), new_current}
        else
          {max, 0}
        end
      end)

    max_count
  end
end
