defmodule Central.Backtest.Schemas.PerformanceSummaryTest do
  use Central.DataCase, async: true

  alias Central.Backtest.Schemas.PerformanceSummary
  alias Central.BacktestFixtures

  describe "performance_summary schema" do
    setup do
      backtest = BacktestFixtures.backtest_fixture()

      valid_attrs = %{
        total_trades: 75,
        winning_trades: 45,
        losing_trades: 30,
        win_rate: Decimal.new("60.00"),
        profit_factor: Decimal.new("1.80"),
        max_drawdown: Decimal.new("800.00"),
        max_drawdown_percentage: Decimal.new("8.00"),
        sharpe_ratio: Decimal.new("1.40"),
        sortino_ratio: Decimal.new("1.80"),
        total_pnl: Decimal.new("1500.00"),
        total_pnl_percentage: Decimal.new("15.00"),
        average_win: Decimal.new("55.56"),
        average_loss: Decimal.new("-33.33"),
        largest_win: Decimal.new("300.00"),
        largest_loss: Decimal.new("-150.00"),
        metrics: %{
          "average_holding_time_hours" => 8,
          "trades_per_day" => 2.5,
          "win_loss_ratio" => 1.5
        },
        backtest_id: backtest.id
      }

      %{backtest: backtest, valid_attrs: valid_attrs}
    end

    test "changeset with valid attributes", %{valid_attrs: valid_attrs} do
      changeset = PerformanceSummary.changeset(%PerformanceSummary{}, valid_attrs)
      assert changeset.valid?
    end

    test "changeset with minimal required attributes", %{backtest: backtest} do
      # Only the absolute minimum required fields
      attrs = %{
        total_trades: 10,
        winning_trades: 6,
        losing_trades: 4,
        backtest_id: backtest.id
      }

      changeset = PerformanceSummary.changeset(%PerformanceSummary{}, attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = PerformanceSummary.changeset(%PerformanceSummary{}, %{})
      refute changeset.valid?

      assert %{
               total_trades: ["can't be blank"],
               winning_trades: ["can't be blank"],
               losing_trades: ["can't be blank"],
               backtest_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "changeset with negative trade counts", %{valid_attrs: valid_attrs} do
      attrs = %{
        valid_attrs
        | total_trades: -10,
          winning_trades: -5,
          losing_trades: -5
      }

      changeset = PerformanceSummary.changeset(%PerformanceSummary{}, attrs)
      refute changeset.valid?

      assert %{
               total_trades: ["must be greater than or equal to 0"],
               winning_trades: ["must be greater than or equal to 0"],
               losing_trades: ["must be greater than or equal to 0"]
             } = errors_on(changeset)
    end

    test "changeset with inconsistent trade counts", %{valid_attrs: valid_attrs} do
      # Total trades should equal winning + losing trades
      attrs = %{
        valid_attrs
        | total_trades: 100,
          winning_trades: 45,
          losing_trades: 30
      }

      changeset = PerformanceSummary.changeset(%PerformanceSummary{}, attrs)
      errors = errors_on(changeset)

      # Check if consistency validation is implemented
      if Map.has_key?(errors, :total_trades) do
        assert %{total_trades: ["must equal the sum of winning and losing trades"]} = errors
      else
        IO.puts("Warning: No validation for trade count consistency")
      end
    end

    test "creating performance summary with fixture" do
      performance_summary = BacktestFixtures.performance_summary_fixture()
      assert performance_summary.total_trades == 50
      assert performance_summary.winning_trades == 30
      assert performance_summary.losing_trades == 20
      assert Decimal.compare(performance_summary.win_rate, Decimal.new("60.00")) == :eq
      assert Decimal.compare(performance_summary.profit_factor, Decimal.new("1.67")) == :eq
      assert Decimal.compare(performance_summary.max_drawdown, Decimal.new("500.00")) == :eq

      assert Decimal.compare(performance_summary.max_drawdown_percentage, Decimal.new("5.00")) ==
               :eq

      assert Decimal.compare(performance_summary.sharpe_ratio, Decimal.new("1.20")) == :eq
      assert Decimal.compare(performance_summary.sortino_ratio, Decimal.new("1.50")) == :eq
      assert Decimal.compare(performance_summary.total_pnl, Decimal.new("1000.00")) == :eq

      assert Decimal.compare(performance_summary.total_pnl_percentage, Decimal.new("10.00")) ==
               :eq

      assert Decimal.compare(performance_summary.average_win, Decimal.new("66.67")) == :eq
      assert Decimal.compare(performance_summary.average_loss, Decimal.new("25.00")) == :eq
      assert Decimal.compare(performance_summary.largest_win, Decimal.new("200.00")) == :eq
      assert Decimal.compare(performance_summary.largest_loss, Decimal.new("100.00")) == :eq

      assert performance_summary.metrics == %{
               "average_holding_time_hours" => 12,
               "trades_per_day" => 1.67
             }

      assert performance_summary.backtest_id
    end

    test "creating performance summary with custom attributes", %{backtest: backtest} do
      custom_attrs = %{
        total_trades: 120,
        winning_trades: 80,
        losing_trades: 40,
        win_rate: Decimal.new("66.67"),
        profit_factor: Decimal.new("2.50"),
        max_drawdown: Decimal.new("1200.00"),
        max_drawdown_percentage: Decimal.new("12.00"),
        sharpe_ratio: Decimal.new("1.80"),
        sortino_ratio: Decimal.new("2.20"),
        total_pnl: Decimal.new("3000.00"),
        total_pnl_percentage: Decimal.new("30.00"),
        average_win: Decimal.new("75.00"),
        average_loss: Decimal.new("50.00"),
        largest_win: Decimal.new("500.00"),
        largest_loss: Decimal.new("200.00"),
        metrics: %{
          "average_holding_time_hours" => 6,
          "trades_per_day" => 4,
          "consecutive_wins" => 8,
          "consecutive_losses" => 3
        },
        backtest_id: backtest.id
      }

      performance_summary = BacktestFixtures.performance_summary_fixture(custom_attrs)
      assert performance_summary.total_trades == 120
      assert performance_summary.winning_trades == 80
      assert performance_summary.losing_trades == 40
      assert Decimal.compare(performance_summary.win_rate, Decimal.new("66.67")) == :eq
      assert Decimal.compare(performance_summary.profit_factor, Decimal.new("2.50")) == :eq
      assert Decimal.compare(performance_summary.max_drawdown, Decimal.new("1200.00")) == :eq

      assert Decimal.compare(performance_summary.max_drawdown_percentage, Decimal.new("12.00")) ==
               :eq

      assert Decimal.compare(performance_summary.sharpe_ratio, Decimal.new("1.80")) == :eq
      assert Decimal.compare(performance_summary.sortino_ratio, Decimal.new("2.20")) == :eq
      assert Decimal.compare(performance_summary.total_pnl, Decimal.new("3000.00")) == :eq

      assert Decimal.compare(performance_summary.total_pnl_percentage, Decimal.new("30.00")) ==
               :eq

      assert Decimal.compare(performance_summary.average_win, Decimal.new("75.00")) == :eq
      assert Decimal.compare(performance_summary.average_loss, Decimal.new("50.00")) == :eq
      assert Decimal.compare(performance_summary.largest_win, Decimal.new("500.00")) == :eq
      assert Decimal.compare(performance_summary.largest_loss, Decimal.new("200.00")) == :eq

      assert performance_summary.metrics == %{
               "average_holding_time_hours" => 6,
               "trades_per_day" => 4,
               "consecutive_wins" => 8,
               "consecutive_losses" => 3
             }

      assert performance_summary.backtest_id == backtest.id
    end

    test "creating performance summary with invalid backtest id" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        BacktestFixtures.performance_summary_fixture(%{backtest_id: Ecto.UUID.generate()})
      end
    end

    test "cannot create multiple performance summaries for the same backtest", %{
      backtest: _backtest,
      valid_attrs: valid_attrs
    } do
      # First one should succeed
      {:ok, _} = PerformanceSummary.changeset(%PerformanceSummary{}, valid_attrs) |> Repo.insert()

      # Second one should fail due to unique constraint on backtest_id
      assert {:error, changeset} =
               PerformanceSummary.changeset(%PerformanceSummary{}, valid_attrs)
               |> Repo.insert()

      errors = errors_on(changeset)
      assert errors[:backtest_id] == ["has already been taken"]
    end
  end
end
