## MarketSync Worker Task Summary

| Task                                           | Handled by `MarketSync` Worker? | Notes                                                                      |
| :--------------------------------------------- | :-----------------------------: | :------------------------------------------------------------------------- |
| **Core Syncing Tasks**                         |                                 |                                                                            |
| Schedule Periodic Data Fetches                 |               ✅                | Runs at a configured interval (e.g., every hour).                          |
| Trigger Manual/On-Demand Syncs               |               ✅                | Can be triggered externally (e.g., by UI if data is missing).              |
| Determine Time Range for Fetching              |               ✅                | Finds the latest timestamp in DB to fetch only new data.                   |
| Fetch Historical Candlesticks (Klines)         |               ✅                | Uses `BinanceClient` to call `GET /api/v3/klines`.                         |
| Handle API Call Retries                      |               ✅                | Retries failed API calls multiple times.                                   |
| Basic Data Completeness Validation             |               ✅                | Checks if a reasonable amount of expected data was received.               |
| Parse API Response Data                      |               ✅                | Converts numbers to Decimals, handles timestamps.                          |
| Insert/Upsert Data into Database             |               ✅                | Stores fetched candles in the `market_data` table, avoiding duplicates.    |
| Log Sync Progress and Errors                 |               ✅                | Provides visibility into the sync process.                                 |
| Manage Internal Sync State                     |               ✅                | Tracks if a sync is running, last/next sync times.                         |
| **Related Tasks (Not Handled by Worker)**      |                                 |                                                                            |
| Fetch Real-time Market Data (WebSockets)     |               ❌                | Worker focuses only on historical REST API fetches.                        |
| Fetch Order Book Depth (`/api/v3/depth`)       |               ❌                | Focused solely on klines.                                                  |
| Fetch Recent Trades (`/api/v3/trades`)         |               ❌                | Focused solely on klines.                                                  |
| Fetch Ticker Information (`/api/v3/ticker/*`)  |               ❌                | Focused solely on klines.                                                  |
| Fetch Average Price (`/api/v3/avgPrice`)       |               ❌                | Focused solely on klines.                                                  |
| Fetch Exchange Info (`/api/v3/exchangeInfo`) |               ❌                | Worker doesn't fetch trading rules, symbol precision, etc.                 |
| Place/Manage Trading Orders                  |               ❌                | This worker is only for fetching market *data*, not trading.               |
| Fetch Account/User Data                      |               ❌                | Does not interact with authenticated account endpoints.                    |
| Manage ETS Cache                             |               ❌                | Data caching logic resides in `Central.Backtest.Contexts.MarketData`.      |
| Serve Data to UI / Backtests                 |               ❌                | Data retrieval is handled by other modules like `MarketDataLoader` and `MarketDataHandler`. |
| Calculate Technical Indicators                 |               ❌                | Stores raw OHLCV data; analysis happens elsewhere.                         | 