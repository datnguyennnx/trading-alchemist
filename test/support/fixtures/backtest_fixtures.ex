defmodule Central.BacktestFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Central.Backtest` context.
  """

  alias Central.Repo
  alias Central.AccountsFixtures
  alias Central.Backtest.Schemas.{MarketData, Strategy, Backtest, Trade, PerformanceSummary}

  @doc """
  Generate a market_data.
  """
  def market_data_fixture(attrs \\ %{}) do
    {:ok, market_data} =
      attrs
      |> Enum.into(%{
        symbol: "BTCUSDT",
        timeframe: "1h",
        timestamp: DateTime.utc_now() |> DateTime.truncate(:second),
        open: Decimal.new("50000.00000000"),
        high: Decimal.new("51000.00000000"),
        low: Decimal.new("49000.00000000"),
        close: Decimal.new("50500.00000000"),
        volume: Decimal.new("100.00000000"),
        source: "binance"
      })
      |> then(&MarketData.changeset(%MarketData{}, &1))
      |> Repo.insert()

    market_data
  end

  @doc """
  Generate a strategy.
  """
  def strategy_fixture(attrs \\ %{}) do
    # Create a user first, ensuring we have a valid UUID
    user =
      if Map.has_key?(attrs, :user) do
        attrs.user
      else
        AccountsFixtures.user_fixture()
      end

    # Get attributes with defaults
    attrs =
      %{
        name: "Test Strategy",
        description: "A strategy for testing",
        config: %{
          "risk_percentage" => 1,
          "take_profit" => 3,
          "stop_loss" => 2
        },
        entry_rules: %{
          "conditions" => [
            %{"indicator" => "price", "comparison" => "above", "value" => 50000}
          ]
        },
        exit_rules: %{
          "conditions" => [
            %{"indicator" => "price", "comparison" => "below", "value" => 48000}
          ]
        },
        is_active: true,
        is_public: false,
        user_id: user.id
      }
      |> Map.merge(Map.drop(attrs, [:user]))

    # Create and return the strategy
    {:ok, strategy} =
      %Strategy{}
      |> Strategy.changeset(attrs)
      |> Repo.insert()

    strategy
  end

  @doc """
  Generate a backtest.
  """
  def backtest_fixture(attrs \\ %{}) do
    # Create a user first, ensuring we have a valid integer ID
    user =
      if Map.has_key?(attrs, :user) do
        attrs.user
      else
        AccountsFixtures.user_fixture()
      end

    # Get the strategy, creating one if not provided
    strategy =
      if Map.has_key?(attrs, :strategy) do
        attrs.strategy
      else
        strategy_fixture(%{user: user})
      end

    # Prepare attributes with defaults and user/strategy IDs
    attrs =
      %{
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-31 23:59:59Z],
        symbol: "BTCUSDT",
        timeframe: "1h",
        initial_balance: Decimal.new("10000.00"),
        final_balance: Decimal.new("11000.00"),
        status: :completed,
        metadata: %{
          "execution_time_ms" => 5000,
          "candles_processed" => 744
        },
        strategy_id: strategy.id,
        user_id: user.id
      }
      |> Map.merge(Map.drop(attrs, [:user, :strategy]))

    # Create and return the backtest
    {:ok, backtest} =
      %Backtest{}
      |> Backtest.changeset(attrs)
      |> Repo.insert()

    backtest
  end

  @doc """
  Generate a trade.
  """
  def trade_fixture(attrs \\ %{}) do
    # Get the backtest, creating one if not provided
    backtest =
      if Map.has_key?(attrs, :backtest) do
        attrs.backtest
      else
        backtest_fixture()
      end

    # Prepare attributes with defaults and backtest ID
    attrs =
      %{
        entry_time: ~U[2025-01-05 10:00:00Z],
        entry_price: Decimal.new("50000.00"),
        exit_time: ~U[2025-01-05 22:00:00Z],
        exit_price: Decimal.new("51500.00"),
        quantity: Decimal.new("0.1"),
        side: :long,
        pnl: Decimal.new("150.00"),
        pnl_percentage: Decimal.new("3.00"),
        fees: Decimal.new("5.00"),
        tags: ["trend_following", "breakout"],
        entry_reason: "price_breakout",
        exit_reason: "take_profit",
        metadata: %{
          "risk_reward_ratio" => 1.5
        },
        backtest_id: backtest.id
      }
      |> Map.merge(Map.drop(attrs, [:backtest]))

    # Create and return the trade
    result =
      %Trade{}
      |> Trade.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, trade} -> trade
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end

  @doc """
  Generate a performance_summary.
  """
  def performance_summary_fixture(attrs \\ %{}) do
    # Get the backtest, creating one if not provided
    backtest =
      if Map.has_key?(attrs, :backtest) do
        attrs.backtest
      else
        backtest_fixture()
      end

    # Prepare attributes with defaults and backtest ID
    attrs =
      %{
        total_trades: 50,
        winning_trades: 30,
        losing_trades: 20,
        win_rate: Decimal.new("60.00"),
        profit_factor: Decimal.new("1.67"),
        max_drawdown: Decimal.new("500.00"),
        max_drawdown_percentage: Decimal.new("5.00"),
        sharpe_ratio: Decimal.new("1.20"),
        sortino_ratio: Decimal.new("1.50"),
        total_pnl: Decimal.new("1000.00"),
        total_pnl_percentage: Decimal.new("10.00"),
        average_win: Decimal.new("66.67"),
        average_loss: Decimal.new("25.00"),
        largest_win: Decimal.new("200.00"),
        largest_loss: Decimal.new("100.00"),
        metrics: %{
          "average_holding_time_hours" => 12,
          "trades_per_day" => 1.67
        },
        backtest_id: backtest.id
      }
      |> Map.merge(Map.drop(attrs, [:backtest]))

    # Create and return the performance_summary
    result =
      %PerformanceSummary{}
      |> PerformanceSummary.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, performance_summary} -> performance_summary
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end
end
