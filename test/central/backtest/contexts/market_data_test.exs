defmodule Central.Backtest.Contexts.MarketDataTest do
  use Central.DataCase, async: true

  alias Central.Backtest.Contexts.MarketData
  alias Central.BacktestFixtures

  describe "market_data context" do
    setup do
      # Clean ETS cache to ensure consistent test results
      try do
        :ets.delete_all_objects(MarketData.cache_name())
      rescue
        _ -> MarketData.init_cache()
      end

      # Create multiple market data records for different symbols and timeframes
      btc_1h =
        BacktestFixtures.market_data_fixture(%{
          symbol: "BTCUSDT",
          timeframe: "1h",
          timestamp: ~U[2025-01-01 00:00:00Z]
        })

      btc_1h_2 =
        BacktestFixtures.market_data_fixture(%{
          symbol: "BTCUSDT",
          timeframe: "1h",
          timestamp: ~U[2025-01-01 01:00:00Z]
        })

      btc_4h =
        BacktestFixtures.market_data_fixture(%{
          symbol: "BTCUSDT",
          timeframe: "4h",
          timestamp: ~U[2025-01-01 00:00:00Z]
        })

      eth_1h =
        BacktestFixtures.market_data_fixture(%{
          symbol: "ETHUSDT",
          timeframe: "1h",
          timestamp: ~U[2025-01-01 00:00:00Z]
        })

      %{
        btc_1h: btc_1h,
        btc_1h_2: btc_1h_2,
        btc_4h: btc_4h,
        eth_1h: eth_1h
      }
    end

    test "list_symbols/0 returns all unique symbols" do
      symbols = MarketData.list_symbols()
      assert length(symbols) == 2
      assert "BTCUSDT" in symbols
      assert "ETHUSDT" in symbols
    end

    test "list_timeframes/0 returns all unique timeframes" do
      timeframes = MarketData.list_timeframes()
      assert length(timeframes) == 2
      assert "1h" in timeframes
      assert "4h" in timeframes
    end

    test "list_symbols/0 caches results", %{btc_1h: _btc_1h} do
      # First call should hit the database
      symbols1 = MarketData.list_symbols()
      assert "BTCUSDT" in symbols1
      assert "ETHUSDT" in symbols1

      # Insert a new symbol
      BacktestFixtures.market_data_fixture(%{
        symbol: "SOLUSDT",
        timeframe: "1h",
        timestamp: ~U[2025-01-01 00:00:00Z]
      })

      # Second call should return cached results (without SOLUSDT)
      symbols2 = MarketData.list_symbols()
      assert symbols2 == symbols1
      refute "SOLUSDT" in symbols2

      # Clear cache
      :ets.delete(MarketData.cache_name(), :symbols)

      # Third call should hit the database again (with SOLUSDT)
      symbols3 = MarketData.list_symbols()
      assert "SOLUSDT" in symbols3
      assert length(symbols3) == 3
    end

    test "get_candles/4 returns candles for specified range", %{
      btc_1h: btc_1h,
      btc_1h_2: btc_1h_2
    } do
      start_time = ~U[2025-01-01 00:00:00Z]
      end_time = ~U[2025-01-01 01:00:00Z]

      candles = MarketData.get_candles("BTCUSDT", "1h", start_time, end_time)

      assert length(candles) == 2
      first_candle = Enum.at(candles, 0)
      second_candle = Enum.at(candles, 1)

      assert first_candle.timestamp == btc_1h.timestamp
      assert Decimal.equal?(first_candle.open, btc_1h.open)
      assert Decimal.equal?(first_candle.close, btc_1h.close)

      assert second_candle.timestamp == btc_1h_2.timestamp
      assert Decimal.equal?(second_candle.open, btc_1h_2.open)
      assert Decimal.equal?(second_candle.close, btc_1h_2.close)
    end

    test "get_candles/4 returns empty list for non-existent data" do
      start_time = ~U[2025-02-01 00:00:00Z]
      end_time = ~U[2025-02-01 01:00:00Z]

      candles = MarketData.get_candles("NONEXISTENT", "1h", start_time, end_time)
      assert candles == []
    end

    test "get_latest_candle/2 returns most recent candle", %{btc_1h: _btc_1h, btc_1h_2: btc_1h_2} do
      latest_candle = MarketData.get_latest_candle("BTCUSDT", "1h")

      # btc_1h_2 is more recent
      assert latest_candle.timestamp == btc_1h_2.timestamp
      assert Decimal.equal?(latest_candle.open, btc_1h_2.open)
      assert Decimal.equal?(latest_candle.close, btc_1h_2.close)
    end

    test "get_latest_candle/2 returns nil for non-existent data" do
      latest_candle = MarketData.get_latest_candle("NONEXISTENT", "1h")
      assert latest_candle == nil
    end

    test "get_oldest_candle/2 returns oldest candle", %{btc_1h: btc_1h, btc_1h_2: _btc_1h_2} do
      oldest_candle = MarketData.get_oldest_candle("BTCUSDT", "1h")

      # btc_1h is older
      assert oldest_candle.timestamp == btc_1h.timestamp
      assert Decimal.equal?(oldest_candle.open, btc_1h.open)
      assert Decimal.equal?(oldest_candle.close, btc_1h.close)
    end

    test "get_date_range/2 returns min and max dates for a symbol/timeframe", %{
      btc_1h: btc_1h,
      btc_1h_2: btc_1h_2
    } do
      {min_date, max_date} = MarketData.get_date_range("BTCUSDT", "1h")

      assert min_date == btc_1h.timestamp
      assert max_date == btc_1h_2.timestamp
    end

    test "get_date_range/2 returns nil for non-existent data" do
      result = MarketData.get_date_range("NONEXISTENT", "1h")
      assert result == {nil, nil}
    end
  end
end
