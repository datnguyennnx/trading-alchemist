defmodule Central.Backtest.Schemas.MarketDataTest do
  use Central.DataCase, async: true

  alias Central.Backtest.Schemas.MarketData
  alias Central.BacktestFixtures

  describe "market_data schema" do
    @valid_attrs %{
      symbol: "ETHUSDT",
      timeframe: "1h",
      timestamp: ~U[2025-01-01 00:00:00Z],
      open: Decimal.new("3000.00"),
      high: Decimal.new("3100.00"),
      low: Decimal.new("2900.00"),
      close: Decimal.new("3050.00"),
      volume: Decimal.new("10.50"),
      source: "binance"
    }

    test "changeset with valid attributes" do
      changeset = MarketData.changeset(%MarketData{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      # Missing required fields
      changeset = MarketData.changeset(%MarketData{}, %{})
      refute changeset.valid?

      assert %{
               symbol: ["can't be blank"],
               timeframe: ["can't be blank"],
               timestamp: ["can't be blank"],
               open: ["can't be blank"],
               high: ["can't be blank"],
               low: ["can't be blank"],
               close: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "changeset with negative price values" do
      invalid_attrs = %{
        @valid_attrs
        | open: Decimal.new("-100.00"),
          high: Decimal.new("-90.00"),
          low: Decimal.new("-110.00"),
          close: Decimal.new("-95.00")
      }

      changeset = MarketData.changeset(%MarketData{}, invalid_attrs)
      refute changeset.valid?

      assert %{
               open: ["must be greater than or equal to 0"],
               high: ["must be greater than or equal to 0"],
               low: ["must be greater than or equal to 0"],
               close: ["must be greater than or equal to 0"]
             } = errors_on(changeset)
    end

    test "changeset with negative volume" do
      invalid_attrs = %{@valid_attrs | volume: Decimal.new("-10.00")}
      changeset = MarketData.changeset(%MarketData{}, invalid_attrs)
      refute changeset.valid?
      assert %{volume: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "changeset with invalid timeframe" do
      invalid_attrs = %{@valid_attrs | timeframe: "invalid"}
      changeset = MarketData.changeset(%MarketData{}, invalid_attrs)
      # Note: The MarketData schema doesn't validate timeframe values,
      # but it might be a good addition to the schema validation
      assert changeset.valid?
    end

    test "creating market data with fixture" do
      market_data = BacktestFixtures.market_data_fixture()
      assert market_data.symbol == "BTCUSDT"
      assert market_data.timeframe == "1h"
      assert %DateTime{} = market_data.timestamp
      assert Decimal.equal?(market_data.open, Decimal.new("50000.00000000"))
      assert Decimal.equal?(market_data.high, Decimal.new("51000.00000000"))
      assert Decimal.equal?(market_data.low, Decimal.new("49000.00000000"))
      assert Decimal.equal?(market_data.close, Decimal.new("50500.00000000"))
      assert Decimal.equal?(market_data.volume, Decimal.new("100.00000000"))
      assert market_data.source == "binance"
    end

    test "creating market data with custom attributes" do
      custom_attrs = %{
        symbol: "SOLUSDT",
        timeframe: "4h",
        timestamp: ~U[2025-01-02 00:00:00Z],
        open: Decimal.new("200.00"),
        high: Decimal.new("220.00"),
        low: Decimal.new("195.00"),
        close: Decimal.new("215.00"),
        volume: Decimal.new("1000.00"),
        source: "custom_source"
      }

      market_data = BacktestFixtures.market_data_fixture(custom_attrs)
      assert market_data.symbol == "SOLUSDT"
      assert market_data.timeframe == "4h"
      assert market_data.timestamp == ~U[2025-01-02 00:00:00Z]
      assert Decimal.equal?(market_data.open, Decimal.new("200.00"))
      assert Decimal.equal?(market_data.high, Decimal.new("220.00"))
      assert Decimal.equal?(market_data.low, Decimal.new("195.00"))
      assert Decimal.equal?(market_data.close, Decimal.new("215.00"))
      assert Decimal.equal?(market_data.volume, Decimal.new("1000.00"))
      assert market_data.source == "custom_source"
    end

    test "cannot create duplicate market data for same symbol, timeframe, timestamp, source" do
      # First, insert the initial market data
      BacktestFixtures.market_data_fixture(@valid_attrs)

      # Then, try to insert a duplicate and expect an error
      assert_raise Ecto.ConstraintError, fn ->
        MarketData.changeset(%MarketData{}, @valid_attrs)
        |> Repo.insert!()
      end
    end
  end
end
