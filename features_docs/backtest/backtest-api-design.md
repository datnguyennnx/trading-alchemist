# Backtest System API Design

This document outlines the API design for the Backtest System, including RESTful endpoints, WebSocket channels, and internal APIs. The design follows RESTful principles and aligns with the system's architecture.

## 1. REST API Endpoints

### 1.1 Authentication

```
POST /api/sessions
```
- **Description**: Create a new user session (login)
- **Request Body**:
  ```json
  {
    "email": "string",
    "password": "string"
  }
  ```
- **Response** (200):
  ```json
  {
    "token": "string",
    "user": {
      "id": "uuid",
      "email": "string",
      "name": "string"
    }
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid credentials
  - 422: Unprocessable Entity - Invalid request format

```
DELETE /api/sessions
```
- **Description**: End user session (logout)
- **Headers**: Authorization: Bearer {token}
- **Response** (204): No Content
- **Error Responses**: 
  - 401: Unauthorized - Invalid token

### 1.2 Strategies

```
GET /api/strategies
```
- **Description**: List user's strategies
- **Headers**: Authorization: Bearer {token}
- **Query Parameters**:
  - `is_active`: boolean - Filter by active status
  - `page`: integer - Page number for pagination
  - `per_page`: integer - Items per page
- **Response** (200):
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "name": "string",
        "description": "string",
        "is_active": boolean,
        "is_public": boolean,
        "created_at": "datetime",
        "updated_at": "datetime"
      }
    ],
    "meta": {
      "page": integer,
      "per_page": integer,
      "total_pages": integer,
      "total_count": integer
    }
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token

```
POST /api/strategies
```
- **Description**: Create a new strategy
- **Headers**: Authorization: Bearer {token}
- **Request Body**:
  ```json
  {
    "name": "string",
    "description": "string",
    "entry_rules": {
      "operator": "and|or",
      "conditions": [
        {
          "indicator": "string",
          "comparator": "string",
          "value": "number|string",
          "params": {
            "period": "number",
            "source": "string"
          }
        }
      ]
    },
    "exit_rules": {
      "operator": "and|or",
      "conditions": [
        {
          "indicator": "string",
          "comparator": "string",
          "value": "number|string",
          "params": {
            "period": "number",
            "source": "string"
          }
        }
      ]
    },
    "config": {
      "position_sizing": "string",
      "risk_percentage": "number",
      "stop_loss": "number",
      "take_profit": "number"
    },
    "is_active": boolean,
    "is_public": boolean
  }
  ```
- **Response** (201):
  ```json
  {
    "id": "uuid",
    "name": "string",
    "description": "string",
    "entry_rules": "object",
    "exit_rules": "object",
    "config": "object",
    "is_active": boolean,
    "is_public": boolean,
    "created_at": "datetime",
    "updated_at": "datetime"
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 422: Unprocessable Entity - Validation errors

```
GET /api/strategies/:id
```
- **Description**: Get a specific strategy
- **Headers**: Authorization: Bearer {token}
- **Response** (200):
  ```json
  {
    "id": "uuid",
    "name": "string",
    "description": "string",
    "entry_rules": "object",
    "exit_rules": "object",
    "config": "object",
    "is_active": boolean,
    "is_public": boolean,
    "created_at": "datetime",
    "updated_at": "datetime"
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 403: Forbidden - Not owner of strategy
  - 404: Not Found - Strategy doesn't exist

```
PUT /api/strategies/:id
```
- **Description**: Update an existing strategy
- **Headers**: Authorization: Bearer {token}
- **Request Body**: Same as POST /api/strategies
- **Response** (200): Same as GET /api/strategies/:id
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 403: Forbidden - Not owner of strategy
  - 404: Not Found - Strategy doesn't exist
  - 422: Unprocessable Entity - Validation errors

```
DELETE /api/strategies/:id
```
- **Description**: Delete a strategy
- **Headers**: Authorization: Bearer {token}
- **Response** (204): No Content
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 403: Forbidden - Not owner of strategy
  - 404: Not Found - Strategy doesn't exist

### 1.3 Backtests

```
GET /api/backtests
```
- **Description**: List user's backtests
- **Headers**: Authorization: Bearer {token}
- **Query Parameters**:
  - `strategy_id`: uuid - Filter by strategy
  - `status`: string - Filter by status (pending, running, completed, failed)
  - `symbol`: string - Filter by symbol
  - `page`: integer - Page number for pagination
  - `per_page`: integer - Items per page
- **Response** (200):
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "strategy_id": "uuid",
        "strategy_name": "string",
        "symbol": "string",
        "timeframe": "string",
        "start_time": "datetime",
        "end_time": "datetime",
        "initial_balance": "decimal",
        "final_balance": "decimal",
        "status": "string",
        "created_at": "datetime",
        "updated_at": "datetime"
      }
    ],
    "meta": {
      "page": integer,
      "per_page": integer,
      "total_pages": integer,
      "total_count": integer
    }
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token

```
POST /api/backtests
```
- **Description**: Create a new backtest
- **Headers**: Authorization: Bearer {token}
- **Request Body**:
  ```json
  {
    "strategy_id": "uuid",
    "symbol": "string",
    "timeframe": "string",
    "start_time": "datetime",
    "end_time": "datetime",
    "initial_balance": "decimal",
    "metadata": {
      "leverage": "number",
      "commission": "number"
    }
  }
  ```
- **Response** (202):
  ```json
  {
    "id": "uuid",
    "strategy_id": "uuid",
    "symbol": "string",
    "timeframe": "string",
    "start_time": "datetime",
    "end_time": "datetime",
    "initial_balance": "decimal",
    "status": "pending",
    "created_at": "datetime",
    "updated_at": "datetime"
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 404: Not Found - Strategy doesn't exist
  - 422: Unprocessable Entity - Validation errors

```
GET /api/backtests/:id
```
- **Description**: Get a specific backtest
- **Headers**: Authorization: Bearer {token}
- **Response** (200):
  ```json
  {
    "id": "uuid",
    "strategy_id": "uuid",
    "strategy_name": "string",
    "symbol": "string",
    "timeframe": "string",
    "start_time": "datetime",
    "end_time": "datetime",
    "initial_balance": "decimal",
    "final_balance": "decimal",
    "status": "string",
    "metadata": "object",
    "created_at": "datetime",
    "updated_at": "datetime",
    "performance_summary": {
      "total_trades": integer,
      "winning_trades": integer,
      "losing_trades": integer,
      "win_rate": "decimal",
      "profit_factor": "decimal",
      "max_drawdown": "decimal",
      "max_drawdown_percentage": "decimal",
      "sharpe_ratio": "decimal",
      "sortino_ratio": "decimal",
      "total_pnl": "decimal",
      "total_pnl_percentage": "decimal"
    }
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 403: Forbidden - Not owner of backtest
  - 404: Not Found - Backtest doesn't exist

```
DELETE /api/backtests/:id
```
- **Description**: Delete a backtest
- **Headers**: Authorization: Bearer {token}
- **Response** (204): No Content
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 403: Forbidden - Not owner of backtest
  - 404: Not Found - Backtest doesn't exist

```
POST /api/backtests/:id/cancel
```
- **Description**: Cancel a running backtest
- **Headers**: Authorization: Bearer {token}
- **Response** (200):
  ```json
  {
    "id": "uuid",
    "status": "string",
    "updated_at": "datetime"
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 403: Forbidden - Not owner of backtest
  - 404: Not Found - Backtest doesn't exist
  - 422: Unprocessable Entity - Backtest not in a cancellable state

### 1.4 Trades

```
GET /api/backtests/:backtest_id/trades
```
- **Description**: Get trades for a specific backtest
- **Headers**: Authorization: Bearer {token}
- **Query Parameters**:
  - `side`: string - Filter by side (long, short)
  - `result`: string - Filter by result (win, loss)
  - `page`: integer - Page number for pagination
  - `per_page`: integer - Items per page
- **Response** (200):
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "backtest_id": "uuid",
        "entry_time": "datetime",
        "entry_price": "decimal",
        "exit_time": "datetime",
        "exit_price": "decimal",
        "quantity": "decimal",
        "side": "string",
        "pnl": "decimal",
        "pnl_percentage": "decimal",
        "fees": "decimal",
        "entry_reason": "string",
        "exit_reason": "string",
        "created_at": "datetime"
      }
    ],
    "meta": {
      "page": integer,
      "per_page": integer,
      "total_pages": integer,
      "total_count": integer
    }
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 403: Forbidden - Not owner of backtest
  - 404: Not Found - Backtest doesn't exist

### 1.5 Market Data

```
GET /api/market_data/symbols
```
- **Description**: Get available market symbols
- **Headers**: Authorization: Bearer {token}
- **Response** (200):
  ```json
  {
    "data": [
      "BTCUSDT",
      "ETHUSDT",
      "BNBUSDT"
    ]
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token

```
GET /api/market_data/timeframes
```
- **Description**: Get available timeframes
- **Headers**: Authorization: Bearer {token}
- **Response** (200):
  ```json
  {
    "data": [
      "1m",
      "5m",
      "15m",
      "1h",
      "4h",
      "1d"
    ]
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token

```
GET /api/market_data/:symbol/:timeframe
```
- **Description**: Get market data for a specific symbol and timeframe
- **Headers**: Authorization: Bearer {token}
- **Query Parameters**:
  - `start_time`: datetime - Start time for data range
  - `end_time`: datetime - End time for data range
  - `limit`: integer - Maximum number of candles to return
- **Response** (200):
  ```json
  {
    "data": [
      {
        "timestamp": "datetime",
        "open": "decimal",
        "high": "decimal",
        "low": "decimal",
        "close": "decimal",
        "volume": "decimal"
      }
    ]
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 404: Not Found - Data not available for symbol/timeframe
  - 422: Unprocessable Entity - Invalid parameters

### 1.6 Transaction History

```
GET /api/transactions
```
- **Description**: Get user's transaction history
- **Headers**: Authorization: Bearer {token}
- **Query Parameters**:
  - `symbol`: string - Filter by symbol
  - `side`: string - Filter by side (buy, sell)
  - `start_time`: datetime - Filter by transaction time range start
  - `end_time`: datetime - Filter by transaction time range end
  - `page`: integer - Page number for pagination
  - `per_page`: integer - Items per page
- **Response** (200):
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "transaction_time": "datetime",
        "symbol": "string",
        "price": "decimal",
        "quantity": "decimal",
        "side": "string",
        "transaction_type": "string",
        "transaction_id": "string",
        "exchange": "string",
        "is_replayed": boolean,
        "created_at": "datetime"
      }
    ],
    "meta": {
      "page": integer,
      "per_page": integer,
      "total_pages": integer,
      "total_count": integer
    }
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token

```
POST /api/transactions/import
```
- **Description**: Import transaction history from file or exchange
- **Headers**: Authorization: Bearer {token}
- **Request Body**:
  ```json
  {
    "source": "file|exchange",
    "exchange": "string",
    "file_content": "string|base64",
    "file_format": "csv|json",
    "api_credentials": {
      "api_key": "string",
      "api_secret": "string"
    }
  }
  ```
- **Response** (202):
  ```json
  {
    "import_id": "string",
    "status": "pending",
    "message": "Import job queued successfully"
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 422: Unprocessable Entity - Invalid parameters

```
POST /api/transactions/replay
```
- **Description**: Replay transaction history in a backtest context
- **Headers**: Authorization: Bearer {token}
- **Request Body**:
  ```json
  {
    "transaction_ids": ["uuid"],
    "symbol": "string",
    "timeframe": "string",
    "window_before": "string",
    "window_after": "string",
    "metadata": {
      "alternative_entry": "string",
      "alternative_exit": "string"
    }
  }
  ```
- **Response** (202):
  ```json
  {
    "replay_id": "uuid",
    "backtest_id": "uuid",
    "status": "pending",
    "message": "Replay job queued successfully"
  }
  ```
- **Error Responses**:
  - 401: Unauthorized - Invalid token
  - 404: Not Found - Transactions don't exist
  - 422: Unprocessable Entity - Invalid parameters

## 2. WebSocket Channels

### 2.1 User Channel

```
channel: "user:{user_id}"
```
- **Description**: Personal channel for user-specific events
- **Join Parameters**:
  ```json
  {
    "token": "string"
  }
  ```
- **Events**:
  - **backtest:status_update** - Backtest status changes
    ```json
    {
      "backtest_id": "uuid",
      "status": "string",
      "progress": "number",
      "message": "string"
    }
    ```
  - **transaction:import_update** - Transaction import status updates
    ```json
    {
      "import_id": "string",
      "status": "string",
      "count": "number",
      "message": "string"
    }
    ```

### 2.2 Backtest Channel

```
channel: "backtest:{backtest_id}"
```
- **Description**: Channel for specific backtest events
- **Join Parameters**:
  ```json
  {
    "token": "string"
  }
  ```
- **Events**:
  - **status_update** - Status updates during execution
    ```json
    {
      "status": "string",
      "progress": "number",
      "message": "string"
    }
    ```
  - **trade_executed** - New trade executed
    ```json
    {
      "trade": {
        "id": "uuid",
        "entry_time": "datetime",
        "entry_price": "decimal",
        "quantity": "decimal",
        "side": "string"
      }
    }
    ```
  - **trade_closed** - Trade closed
    ```json
    {
      "trade_id": "uuid",
      "exit_time": "datetime",
      "exit_price": "decimal",
      "pnl": "decimal",
      "pnl_percentage": "decimal"
    }
    ```
  - **metrics_update** - Performance metrics update
    ```json
    {
      "current_balance": "decimal",
      "equity": "decimal",
      "drawdown": "decimal",
      "drawdown_percentage": "decimal",
      "open_positions": "number"
    }
    ```

### 2.3 Market Data Channel

```
channel: "market:{symbol}:{timeframe}"
```
- **Description**: Channel for real-time market data updates
- **Join Parameters**:
  ```json
  {
    "token": "string"
  }
  ```
- **Events**:
  - **candle_update** - New or updated candle
    ```json
    {
      "timestamp": "datetime",
      "open": "decimal",
      "high": "decimal",
      "low": "decimal",
      "close": "decimal",
      "volume": "decimal",
      "is_closed": boolean
    }
    ```
  - **ticker_update** - Real-time price update
    ```json
    {
      "timestamp": "datetime",
      "price": "decimal",
      "volume": "decimal"
    }
    ```

## 3. Internal APIs

### 3.1 Strategy Execution Engine

```elixir
Central.Backtest.Services.StrategyExecutor.execute_backtest(backtest_id)
```
- **Description**: Executes a strategy against historical data
- **Parameters**:
  - `backtest_id`: UUID of the backtest to execute
- **Returns**:
  - `{:ok, result}` - Successfully completed backtest
  - `{:error, reason}` - Failed to execute backtest

```elixir
Central.Backtest.Services.StrategyExecutor.validate_strategy(strategy)
```
- **Description**: Validates a strategy configuration
- **Parameters**:
  - `strategy`: Strategy struct or map
- **Returns**:
  - `{:ok, strategy}` - Valid strategy
  - `{:error, errors}` - Validation errors

### 3.2 Market Data Service

```elixir
Central.Backtest.Contexts.MarketData.get_candles(symbol, timeframe, start_time, end_time)
```
- **Description**: Retrieves historical OHLCV data
- **Parameters**:
  - `symbol`: Trading pair symbol (e.g., "BTCUSDT")
  - `timeframe`: Candle timeframe (e.g., "1h")
  - `start_time`: Start datetime
  - `end_time`: End datetime
- **Returns**: List of candle structs

```elixir
Central.Backtest.Services.Binance.Historical.fetch_historical_data(symbol, timeframe, start_time, end_time)
```
- **Description**: Fetches historical data from Binance
- **Parameters**:
  - `symbol`: Trading pair symbol
  - `timeframe`: Candle timeframe
  - `start_time`: Start datetime
  - `end_time`: End datetime
- **Returns**:
  - `{:ok, data}` - Successfully fetched data
  - `{:error, reason}` - Failed to fetch data

### 3.3 Performance Analytics

```elixir
Central.Backtest.Services.Performance.generate_performance_summary(backtest_id)
```
- **Description**: Generates performance metrics for a backtest
- **Parameters**:
  - `backtest_id`: UUID of the backtest
- **Returns**: Performance summary struct

```elixir
Central.Backtest.Services.Performance.calculate_drawdown(equity_curve)
```
- **Description**: Calculates maximum drawdown from equity curve
- **Parameters**:
  - `equity_curve`: List of balance points over time
- **Returns**: 
  - `{max_drawdown, max_drawdown_percentage, drawdown_periods}`

### 3.4 Transaction Replay

```elixir
Central.Backtest.Services.TransactionReplay.replay_transaction(transaction_id, backtest_id)
```
- **Description**: Replays a historical transaction in backtest context
- **Parameters**:
  - `transaction_id`: UUID of the transaction to replay
  - `backtest_id`: UUID of the backtest context
- **Returns**:
  - `{:ok, replay_execution}` - Successfully queued replay
  - `{:error, reason}` - Failed to queue replay

### 3.5 Technical Indicators

```elixir
Central.Backtest.Services.Indicators.calculate(indicator_type, data, params)
```
- **Description**: Calculates technical indicator values
- **Parameters**:
  - `indicator_type`: Type of indicator (e.g., :sma, :rsi)
  - `data`: List of price data points
  - `params`: Parameters for the indicator
- **Returns**: List of calculated indicator values

## 4. Error Handling

All API endpoints should return appropriate HTTP status codes and error messages:

- **400 Bad Request**: Invalid request format or parameters
- **401 Unauthorized**: Authentication required or token invalid
- **403 Forbidden**: Authenticated user doesn't have permission
- **404 Not Found**: Requested resource doesn't exist
- **422 Unprocessable Entity**: Request validation failed
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server-side error

Error responses should follow this format:
```json
{
  "error": {
    "code": "string",
    "message": "string",
    "details": [
      {
        "field": "string",
        "message": "string"
      }
    ]
  }
}
```

## 5. Rate Limiting

API endpoints should implement rate limiting to prevent abuse:

- Authentication endpoints: 20 requests per minute per IP
- General API endpoints: 120 requests per minute per user
- Market data endpoints: 300 requests per minute per user
- Backtest creation: 10 requests per minute per user

Rate limit headers should be included in responses:
```
X-RateLimit-Limit: {limit}
X-RateLimit-Remaining: {remaining}
X-RateLimit-Reset: {reset_time}
```

## 6. Versioning

The API should be versioned to allow for future changes:

- Version should be specified in the URL path: `/api/v1/...`
- API documentation should clearly indicate the current version and any deprecated versions
- Breaking changes should only be introduced in new API versions

## 7. API Documentation

Comprehensive API documentation should be provided using OpenAPI/Swagger specification:

- Available at `/api/docs`
- Include sample requests and responses
- Detail all available endpoints, parameters, and response formats
- Provide authentication instructions
- Include rate limiting information 