# Stage 1: Core Infrastructure Implementation

## Overview
In this initial stage, we will focus on setting up the foundation for the backtest system. This includes creating the database schema, implementing the Binance API client, and developing basic market data synchronization mechanisms.

## Implementation Focus

### 1. Database Schema Setup (Week 1)
- Create database migration files for:
  - `market_data` table
  - `strategies` table
  - `backtests` table
  - `trades` table
- Implement Ecto schemas with validations and associations
- Create basic database indices for performance
- **Enable TimescaleDB extension**
- **Convert `market_data` table to TimescaleDB hypertable**

**Priority Tasks:**
1. Set up PostgreSQL database with proper configuration
2. **Enable the TimescaleDB extension in the database**
3. Create main schema migrations with proper constraints and indices
4. **Add migration step to convert `market_data` to a hypertable**
5. Implement Ecto schemas with comprehensive validation logic
6. Write basic seed data for development environment

```elixir
# Sample migration for enabling TimescaleDB and creating market_data hypertable
defmodule Central.Repo.Migrations.EnableTimescaleAndCreateMarketData do
  use Ecto.Migration

  def up do
    # Enable the TimescaleDB extension
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"

    create table(:market_data, primary_key: false) do
      add :symbol, :string, null: false
      add :timeframe, :string, null: false
      add :timestamp, :utc_datetime, null: false
      add :open, :decimal, precision: 18, scale: 8, null: false
      add :high, :decimal, precision: 18, scale: 8, null: false
      add :low, :decimal, precision: 18, scale: 8, null: false
      add :close, :decimal, precision: 18, scale: 8, null: false
      add :volume, :decimal, precision: 24, scale: 8
      add :source, :string, default: "binance"

      timestamps(updated_at: false)
    end

    # Convert the table to a hypertable, partitioned by the timestamp column
    # Choose an appropriate chunk_time_interval based on expected data volume
    execute "SELECT create_hypertable('market_data', 'timestamp', chunk_time_interval => INTERVAL '1 day');"

    # Create indices AFTER converting to hypertable for better performance
    create index(:market_data, [:symbol, :timeframe, :timestamp])
    create index(:market_data, [:symbol, :timeframe, :source])
    create unique_index(:market_data, [:symbol, :timeframe, :timestamp, :source])
  end

  def down do
    # Drop indices first
    drop unique_index(:market_data, [:symbol, :timeframe, :timestamp, :source])
    drop index(:market_data, [:symbol, :timeframe, :source])
    drop index(:market_data, [:symbol, :timeframe, :timestamp])

    # Drop the table (this automatically handles hypertables)
    drop table(:market_data)

    # Optionally disable the extension if no other hypertables exist
    # execute "DROP EXTENSION IF EXISTS timescaledb;"
  end
end
```

### 2. Binance API Client (Week 2)
- Implement HTTP client for Binance REST API
- Create WebSocket client for real-time data
- Develop rate limiting mechanism
- Implement error handling and retry logic

**Priority Tasks:**
1. Implement basic HTTP client with Tesla
2. Create functions for fetching historical klines data
3. Set up WebSocket connection for streaming real-time data
4. Implement rate limit tracking and throttling

```elixir
# Sample Binance API client module
defmodule Central.Backtest.Services.Binance.Client do
  use Tesla
  
  @base_url "https://api.binance.com"
  
  plug Tesla.Middleware.BaseUrl, @base_url
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger
  
  def get_klines(symbol, interval, start_time, end_time, limit \\ 1000) do
    get("/api/v3/klines", query: [
      symbol: String.upcase(symbol),
      interval: interval,
      startTime: DateTime.to_unix(start_time, :millisecond),
      endTime: DateTime.to_unix(end_time, :millisecond),
      limit: limit
    ])
    |> handle_response()
  end
  
  defp handle_response({:ok, %{status: 200, body: body}}), do: {:ok, body}
  defp handle_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp handle_response({:error, reason}), do: {:error, reason}
end
```

### 3. Market Data Synchronization (Week 3)
- Create background workers for data synchronization
- Implement data processing and normalization
- Build data caching mechanisms
- Develop a data integrity verification system

**Priority Tasks:**
1. Create GenServer for background data synchronization
2. Implement data normalization for OHLCV data
3. Set up ETS tables for caching frequent queries
4. Develop context functions for reading market data

```elixir
# Sample market data sync worker
defmodule Central.Backtest.Workers.MarketSyncWorker do
  use GenServer
  alias Central.Backtest.Services.Binance.Client
  alias Central.Backtest.Schema.MarketData
  alias Central.Repo
  
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
  
  def init(args) do
    symbols = args[:symbols] || ["BTCUSDT", "ETHUSDT"]
    timeframes = args[:timeframes] || ["1m", "5m", "15m", "1h", "4h", "1d"]
    
    # Start the scheduler
    schedule_sync()
    
    {:ok, %{symbols: symbols, timeframes: timeframes}}
  end
  
  def handle_info(:sync, state) do
    sync_market_data(state.symbols, state.timeframes)
    schedule_sync()
    {:noreply, state}
  end
  
  defp schedule_sync do
    # Sync every hour
    Process.send_after(self(), :sync, 60 * 60 * 1000)
  end
  
  defp sync_market_data(symbols, timeframes) do
    # Sync recent data for all symbol/timeframe combinations
    for symbol <- symbols, timeframe <- timeframes do
      Task.async(fn -> 
        sync_single_market(symbol, timeframe) 
      end)
    end
    |> Task.await_many(30_000)
  end
  
  defp sync_single_market(symbol, timeframe) do
    # Implementation details for syncing a single market
  end
end
```

### 4. Basic Context API (Week 4)
- Create context modules for business logic
- Implement basic queries and mutations
- Set up error handling and validation
- Develop comprehensive tests

**Priority Tasks:**
1. Create contexts for market data, strategies, and backtests
2. Implement basic CRUD operations for each context
3. Set up validation logic for each operation
4. Write comprehensive test coverage

```elixir
# Sample context module
defmodule Central.Backtest.Contexts.MarketData do
  import Ecto.Query
  alias Central.Repo
  alias Central.Backtest.Schema.MarketData
  
  def list_symbols do
    from(m in MarketData, select: m.symbol, distinct: true)
    |> Repo.all()
  end
  
  def list_timeframes do
    from(m in MarketData, select: m.timeframe, distinct: true)
    |> Repo.all()
  end
  
  def get_candles(symbol, timeframe, start_time, end_time) do
    from(m in MarketData,
      where: m.symbol == ^symbol and
             m.timeframe == ^timeframe and
             m.timestamp >= ^start_time and
             m.timestamp <= ^end_time,
      # TimescaleDB benefits from ordering by the time dimension
      order_by: [asc: m.timestamp]
    )
    |> Repo.all()
  end
  
  def create_candle(attrs) do
    %MarketData{}
    |> MarketData.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:symbol, :timeframe, :timestamp, :source])
  end
end
```

## Testing Strategy
- Write unit tests for all Ecto schemas
- Create integration tests for the Binance API client
- Develop end-to-end tests for data synchronization
- Implement property-based tests for data validation

## Expected Deliverables
- Fully implemented database schemas and migrations
- Working Binance API client with rate limiting
- Market data synchronization background worker
- Basic context modules for core business logic
- Comprehensive test suite

## Next Steps
After completing Stage 1, we will have the foundation for our backtest system. The next stage will focus on developing the backtest engine, implementing strategy execution, and creating performance analytics tools. 