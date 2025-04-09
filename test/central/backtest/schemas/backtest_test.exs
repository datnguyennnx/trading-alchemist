defmodule Central.Backtest.Schemas.BacktestTest do
  use Central.DataCase, async: true

  alias Central.Backtest.Schemas.Backtest
  alias Central.BacktestFixtures
  alias Central.AccountsFixtures

  describe "backtest schema" do
    setup do
      user = AccountsFixtures.user_fixture()
      strategy = BacktestFixtures.strategy_fixture(%{user: user})

      valid_attrs = %{
        start_time: ~U[2025-02-01 00:00:00Z],
        end_time: ~U[2025-02-28 23:59:59Z],
        symbol: "ADAUSDT",
        timeframe: "4h",
        initial_balance: Decimal.new("5000.00"),
        final_balance: Decimal.new("5500.00"),
        status: :completed,
        metadata: %{
          "execution_time_ms" => 3500,
          "candles_processed" => 168
        },
        strategy_id: strategy.id,
        user_id: user.id
      }

      %{user: user, strategy: strategy, valid_attrs: valid_attrs}
    end

    test "changeset with valid attributes", %{valid_attrs: valid_attrs} do
      changeset = Backtest.changeset(%Backtest{}, valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Backtest.changeset(%Backtest{}, %{})
      refute changeset.valid?

      assert %{
               start_time: ["can't be blank"],
               end_time: ["can't be blank"],
               symbol: ["can't be blank"],
               timeframe: ["can't be blank"],
               initial_balance: ["can't be blank"],
               status: ["can't be blank"],
               strategy_id: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "changeset with negative initial balance", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | initial_balance: Decimal.new("-100.00")}
      changeset = Backtest.changeset(%Backtest{}, attrs)
      refute changeset.valid?
      assert %{initial_balance: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "changeset with invalid timeframe", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | timeframe: "invalid"}
      changeset = Backtest.changeset(%Backtest{}, attrs)
      refute changeset.valid?
      assert %{timeframe: ["is invalid"]} = errors_on(changeset)
    end

    test "timeframe validation accepts valid timeframes", %{valid_attrs: valid_attrs} do
      valid_timeframes = [
        "1m",
        "5m",
        "15m",
        "30m",
        "1h",
        "2h",
        "4h",
        "12h",
        "1d",
        "3d",
        "1w",
        "1M"
      ]

      Enum.each(valid_timeframes, fn timeframe ->
        attrs = %{valid_attrs | timeframe: timeframe}
        changeset = Backtest.changeset(%Backtest{}, attrs)
        assert changeset.valid?, "Timeframe #{timeframe} should be valid"
      end)
    end

    test "validate_dates rejects when end_time is before start_time", %{valid_attrs: valid_attrs} do
      attrs = %{
        valid_attrs
        | end_time: ~U[2025-01-15 00:00:00Z],
          start_time: ~U[2025-01-20 00:00:00Z]
      }

      changeset = Backtest.changeset(%Backtest{}, attrs)

      # Get error map and check that end_time error is present
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :end_time)

      assert Enum.any?(errors.end_time, fn msg ->
               String.contains?(msg, "must be after start time")
             end)
    end

    test "creating backtest with fixture" do
      backtest = BacktestFixtures.backtest_fixture()
      assert backtest.symbol == "BTCUSDT"
      assert backtest.timeframe == "1h"
      assert backtest.start_time == ~U[2025-01-01 00:00:00Z]
      assert backtest.end_time == ~U[2025-01-31 23:59:59Z]
      assert Decimal.compare(backtest.initial_balance, Decimal.new("10000.00")) == :eq
      assert Decimal.compare(backtest.final_balance, Decimal.new("11000.00")) == :eq
      assert backtest.status == :completed

      assert backtest.metadata == %{
               "execution_time_ms" => 5000,
               "candles_processed" => 744
             }

      assert backtest.strategy_id
      assert backtest.user_id
    end

    test "creating backtest with custom attributes", %{user: user, strategy: strategy} do
      custom_attrs = %{
        start_time: ~U[2025-03-01 00:00:00Z],
        end_time: ~U[2025-03-15 23:59:59Z],
        symbol: "LINKUSDT",
        timeframe: "15m",
        initial_balance: Decimal.new("2000.00"),
        final_balance: Decimal.new("2200.00"),
        status: :running,
        metadata: %{
          "execution_time_ms" => 1500,
          "candles_processed" => 1440
        },
        strategy_id: strategy.id,
        user_id: user.id
      }

      backtest = BacktestFixtures.backtest_fixture(custom_attrs)
      assert backtest.symbol == "LINKUSDT"
      assert backtest.timeframe == "15m"
      assert backtest.start_time == ~U[2025-03-01 00:00:00Z]
      assert backtest.end_time == ~U[2025-03-15 23:59:59Z]
      assert Decimal.compare(backtest.initial_balance, Decimal.new("2000.00")) == :eq
      assert Decimal.compare(backtest.final_balance, Decimal.new("2200.00")) == :eq
      assert backtest.status == :running

      assert backtest.metadata == %{
               "execution_time_ms" => 1500,
               "candles_processed" => 1440
             }

      assert backtest.strategy_id == strategy.id
      assert backtest.user_id == user.id
    end

    test "creating backtest with invalid strategy id" do
      user = AccountsFixtures.user_fixture()

      # Create a changeset with a non-UUID string as strategy_id
      attrs = %{
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-31 23:59:59Z],
        symbol: "BTCUSDT",
        timeframe: "1h",
        initial_balance: Decimal.new("10000.00"),
        final_balance: Decimal.new("11000.00"),
        status: :completed,
        metadata: %{"execution_time_ms" => 5000, "candles_processed" => 744},
        # Use a non-existent UUID
        strategy_id: "00000000-0000-0000-0000-000000000000",
        user_id: user.id
      }

      # Attempt to insert should fail with a constraint error
      assert_raise Ecto.InvalidChangesetError, fn ->
        %Backtest{}
        |> Backtest.changeset(attrs)
        |> Repo.insert!()
      end
    end

    test "creating backtest with invalid user id" do
      user = AccountsFixtures.user_fixture()
      strategy = BacktestFixtures.strategy_fixture(%{user: user})

      # Create a changeset with a non-UUID string as user_id
      attrs = %{
        start_time: ~U[2025-01-01 00:00:00Z],
        end_time: ~U[2025-01-31 23:59:59Z],
        symbol: "BTCUSDT",
        timeframe: "1h",
        initial_balance: Decimal.new("10000.00"),
        final_balance: Decimal.new("11000.00"),
        status: :completed,
        metadata: %{"execution_time_ms" => 5000, "candles_processed" => 744},
        strategy_id: strategy.id,
        user_id: "not-a-uuid"
      }

      changeset = Backtest.changeset(%Backtest{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset)[:user_id]
    end
  end
end
