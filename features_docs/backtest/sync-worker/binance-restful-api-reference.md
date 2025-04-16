# Binance Spot REST API Reference Summary

This document summarizes key information about the Binance Spot REST API based on the official documentation.

**Source Documentation:**

*   General API Information: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/general-api-information](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/general-api-information)
*   HTTP Return Codes: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/http-return-codes](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/http-return-codes)
*   Error Codes: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/error-codes](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/error-codes)
*   General Information on Endpoints: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/general-information-on-endpoints](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/general-information-on-endpoints)
*   Limits: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/limits](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/limits)
*   General Endpoints: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/general-endpoints](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/general-endpoints)
*   Market Data Endpoints: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/market-data-endpoints](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/market-data-endpoints) (Refer for specific endpoints)
*   Trading Endpoints: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/trading-endpoints](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/trading-endpoints) (Refer for specific endpoints)
*   Account Endpoints: [https://developers.binance.com/docs/binance-spot-api-docs/rest-api/account-endpoints](https://developers.binance.com/docs/binance-spot-api-docs/rest-api/account-endpoints) (Refer for specific endpoints)

## Base URLs

Multiple base endpoints are available:

*   `https://api.binance.com` (Primary)
*   `https://api-gcp.binance.com`
*   `https://api1.binance.com`
*   `https://api2.binance.com`
*   `https://api3.binance.com`
*   `https://api4.binance.com` (Better performance, potentially less stable)

For public market data only:

*   `https://data-api.binance.vision`

## General Information

*   **Data Format:** All endpoints return JSON objects or arrays.
*   **Data Order:** Data is returned in ascending order (oldest first, newest last).
*   **Timestamps:**
    *   All time/timestamp fields in responses are in **milliseconds** by default.
    *   Microsecond precision can be requested via the header `X-MBX-TIME-UNIT: MICROSECOND`.
    *   Timestamp parameters in requests (`startTime`, `endTime`, `timestamp`) can be in milliseconds or microseconds.
*   **Authentication:** Required for Trading, Account, and User Data Stream endpoints. Typically involves API Key and Signature (HMAC, RSA, or Ed25519 - specifics not detailed in the provided links).

## Parameter Handling

*   **GET:** Parameters must be sent in the `query string`.
*   **POST, PUT, DELETE:** Parameters can be sent in the `query string` or `request body` (`application/x-www-form-urlencoded`).
    *   Mixing parameters between query string and request body is allowed.
    *   If a parameter exists in both, the `query string` value takes precedence.
*   Parameters can be sent in any order.

## HTTP Return Codes

*   `2XX`: Success.
*   `4XX`: Client-side error (malformed request, invalid parameters, etc.).
    *   `403`: WAF (Web Application Firewall) limit violated.
    *   `409`: Used for `cancelReplace` orders where cancellation fails but placement succeeds.
    *   `418`: IP address has been auto-banned for excessive rate limit violations (after receiving 429s). Includes `Retry-After` header (seconds).
    *   `429`: Request rate limit broken. Includes `Retry-After` header (seconds).
*   `5XX`: Server-side error (internal issue on Binance's side).
    *   **Important:** Do **NOT** treat 5XX as a failed operation. The execution status is **UNKNOWN** and might have succeeded.

## Error Codes

*   Endpoints can return a JSON error payload on failure:
    ```json
    {
      "code": -1121,
      "msg": "Invalid symbol."
    }
    ```
*   Specific error codes are defined in the official documentation.

## Rate Limits

*   **IP Based:** Limits are applied per IP address, not per API key.
*   **Weights:** Each endpoint has a `weight`. Heavier operations consume more weight.
*   **Tracking:** Response headers include `X-MBX-USED-WEIGHT-(intervalNum)(intervalLetter)` showing current used weight for different intervals (S=Second, M=Minute, H=Hour, D=Day).
*   **Violation:** Exceeding limits results in `429` (Too Many Requests). Continued violations after `429` lead to `418` (IP Auto-ban).
*   **Bans:** IP bans scale in duration (minutes to days) for repeat offenders.
*   **Exchange Info:** The `/api/v3/exchangeInfo` endpoint details current rate limits (`RAW_REQUESTS`, `REQUEST_WEIGHT`, `ORDERS`).
*   **Order Limits:** There are also limits on the number of open orders per account per interval (`X-MBX-ORDER-COUNT-(intervalNum)(intervalLetter)` header in successful order responses). Exceeding this also results in `429` (without `Retry-After`).

## Key General Endpoints

*   **`GET /api/v3/ping`**:
    *   Tests API connectivity.
    *   Weight: 1
    *   Response: `{}`
*   **`GET /api/v3/time`**:
    *   Tests API connectivity and returns server time.
    *   Weight: 1
    *   Response: `{"serverTime": 1499827319559}` (milliseconds)
*   **`GET /api/v3/exchangeInfo`**:
    *   Provides current exchange trading rules, symbol information (precision, order types, filters, permissions), and rate limits.
    *   Weight: 20 (can be heavy)
    *   Optional Parameters: `symbol`, `symbols`, `permissions`.

## Other Endpoint Categories

Refer to the official documentation links above for detailed lists and parameters for:

*   **Market Data Endpoints:** Fetching prices, depth, trades, klines, tickers, etc.
*   **Trading Endpoints:** Placing, querying, and canceling orders (requires authentication).
*   **Account Endpoints:** Querying account balances, trades, permissions, etc. (requires authentication).
*   **User Data Stream Endpoints (Deprecated):** Used for managing listen keys for WebSocket user data streams (requires authentication). *Note: These specific REST endpoints for stream management are deprecated in favor of WebSocket API or other methods.*

## Detailed Endpoint Lists

### Market Data Endpoints

*   `GET /api/v3/depth` - Order book
*   `GET /api/v3/trades` - Recent trades list
*   `GET /api/v3/historicalTrades` - Old trade lookup (MARKET_DATA)
*   `GET /api/v3/aggTrades` - Compressed/Aggregate trades list
*   `GET /api/v3/klines` - Kline/Candlestick data
*   `GET /api/v3/uiKlines` - Kline/Candlestick data for UI
*   `GET /api/v3/avgPrice` - Current average price
*   `GET /api/v3/ticker/24hr` - 24hr ticker price change statistics
*   `GET /api/v3/ticker/tradingDay` - Trading Day Ticker
*   `GET /api/v3/ticker/price` - Symbol price ticker
*   `GET /api/v3/ticker/bookTicker` - Symbol order book ticker
*   `GET /api/v3/ticker` - Rolling window price change statistics

### Trading Endpoints (Authentication Required)

*   `POST /api/v3/order` - New Order (TRADE)
*   `POST /api/v3/order/test` - Test New Order (TRADE)
*   `GET /api/v3/order` - Query Order (USER_DATA)
*   `DELETE /api/v3/order` - Cancel Order (TRADE)
*   `DELETE /api/v3/openOrders` - Cancel all Open Orders on a Symbol (TRADE)
*   `POST /api/v3/order/cancelReplace` - Cancel an Existing Order and Send a New Order (TRADE)
*   `PUT /api/v3/order/keepPriority` - Order Amend Keep Priority (TRADE)
*   `GET /api/v3/openOrders` - Current Open Orders (USER_DATA)
*   `GET /api/v3/allOrders` - All Orders (USER_DATA)
*   `POST /api/v3/sor/order` - New order using SOR (TRADE)
*   `POST /api/v3/sor/order/test` - Test new order using SOR (TRADE)

### Order List Endpoints (Authentication Required)

*   `POST /api/v3/order/oco` - New OCO (TRADE)
*   `POST /api/v3/orderList` - New Order List (TRADE)
*   `DELETE /api/v3/orderList` - Cancel Order List (TRADE)
*   `GET /api/v3/orderList` - Query Order List (USER_DATA)
*   `GET /api/v3/allOrderList` - Query all Order Lists (USER_DATA)
*   `GET /api/v3/openOrderList` - Query Open Order Lists (USER_DATA)

### Account Endpoints (Authentication Required)

*   `GET /api/v3/account` - Account Information (USER_DATA)
*   `GET /api/v3/myTrades` - Account Trade List (USER_DATA)
*   `GET /api/v3/rateLimit/order` - Query Current Order Count Usage (USER_DATA)
*   `GET /api/v3/preventedMatches` - Query Prevented Matches (USER_DATA)
*   `GET /api/v3/allocations` - Query Allocations (USER_DATA)
*   `GET /api/v3/commissionRates` - Query Commission Rates (USER_DATA)
*   `GET /api/v3/orderAmendment` - Query Order Amendments (USER_DATA)

### User Data Stream Endpoints (Deprecated - Authentication Required)

*   `POST /api/v3/userDataStream` - Create a ListenKey (USER_STREAM)
*   `PUT /api/v3/userDataStream` - Ping/Keep-alive a ListenKey (USER_STREAM)
*   `DELETE /api/v3/userDataStream` - Close a ListenKey (USER_STREAM)

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