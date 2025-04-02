# Backtest System Design Document

## 1. System Overview

The backtest system will allow users to:
- Test trading strategies against historical data
- Visualize trade executions on charts
- Analyze performance metrics
- Stream real-time market data for live testing
- Save and replay historical transactions for consistent analysis

## 2. Folder Structure

```
lib/
├── central/
│   ├── backtest/
│   │   ├── contexts/
│   │   │   ├── strategy.ex        # Strategy management
│   │   │   ├── execution.ex       # Backtest execution
│   │   │   └── analysis.ex        # Results analysis
│   │   ├── schemas/
│   │   │   ├── strategy.ex        # Strategy configuration
│   │   │   ├── trade.ex           # Trade execution records
│   │   │   ├── backtest.ex        # Backtest session
│   │   │   └── market_data.ex     # Historical price data
│   │   ├── services/
│   │   │   ├── binance/
│   │   │   │   ├── client.ex      # Binance API client
│   │   │   │   ├── stream.ex      # WebSocket streams
│   │   │   │   └── historical.ex  # Historical data fetcher
│   │   │   ├── data_processor.ex  # Data transformation
│   │   │   └── performance.ex     # Performance calculations
│   │   ├── validators/            # Strategy validation
│   │   │   ├── rule_validator.ex
│   │   │   └── position_validator.ex
│   │   ├── indicators/            # Technical indicators
│   │   │   ├── moving_average.ex
│   │   │   ├── rsi.ex
│   │   │   └── macd.ex
│   │   ├── risk_management/       # Risk management
│   │   │   ├── position_sizer.ex
│   │   │   └── risk_calculator.ex
│   │   ├── reporting/             # Performance reporting
│   │   │   ├── metrics.ex
│   │   │   └── report_generator.ex
│   │   └── workers/
│   │       ├── market_sync.ex     # Background market data sync
│   │       └── backtest_runner.ex # Backtest execution worker
│   └── market_data/
│       ├── adapters/              # Data source adapters
│       │   ├── binance_adapter.ex
│       │   └── csv_adapter.ex
│       ├── normalizers/           # Data normalization
│       │   └── ohlcv_normalizer.ex
│       └── cache.ex               # Market data caching
├── central_web/
│   ├── live/
│   │   ├── backtest/
│   │   │   ├── strategy_live.ex   # Strategy management UI
│   │   │   ├── execution_live.ex  # Backtest execution UI
│   │   │   ├── results_live.ex    # Results analysis UI
│   │   │   └── components/
│   │   │       ├── strategy_form_component.ex
│   │   │       ├── trade_table_component.ex
│   │   │       ├── performance_metrics_component.ex
│   │   │       └── chart_controls_component.ex
│   │   ├── shared/
│   │   │   └── components/
│   │   │       ├── modal_component.ex
│   │   │       └── notification_component.ex
│   │   └── components/
│   │       ├── chart_component.ex # Reusable chart component
│   │       └── trade_list.ex      # Trade execution list
│   └── templates/
│       └── backtest/              # Static templates
test/
├── central/
│   ├── backtest/
│   │   ├── contexts/
│   │   ├── schemas/
│   │   └── services/
│   │       └── binance/
│   └── market_data/
├── central_web/
│   ├── live/
│   │   └── backtest/
│   └── controllers/
└── support/
    ├── fixtures/
    │   └── market_data_fixtures.ex
    └── mocks/
        └── binance_api_mock.ex
assets/
├── js/
│   ├── hooks/
│   │   ├── tradingview_chart.js
│   │   ├── strategy_editor.js
│   │   └── backtest_controls.js
│   ├── lib/
│   │   └── trading_indicators.js
│   └── app.js
├── css/
│   ├── app.css
│   └── charts.css
└── vendor/
    └── tradingview/
config/
├── config.exs
├── dev.exs
├── prod.exs
├── test.exs
└── runtime.exs
priv/
├── repo/
│   ├── migrations/
│   │   ├── YYYYMMDDHHMMSS_create_strategies.exs
│   │   ├── YYYYMMDDHHMMSS_create_backtests.exs
│   │   ├── YYYYMMDDHHMMSS_create_trades.exs
│   │   └── YYYYMMDDHHMMSS_create_market_data.exs
│   └── seeds/
│       ├── strategy_seeds.exs
│       └── test_market_data_seeds.exs
└── static/
    └── images/
```

## 3. High-Level Architecture
```
+----------------+     +----------------+     +----------------+
|                |     |                |     |                |
|  Load Balancer |---->|  Phoenix App   |---->|  PostgreSQL    |
|                |     |  (Elixir)      |     |  Database      |
+----------------+     +----------------+     +----------------+
       |                       |                      |
       |                       |                      |
+----------------+     +----------------+     +----------------+
|                |     |                |     |                |
|  Redis Cache   |<--->|  Background    |     |  TimescaleDB   |
|                |     |  Workers       |     |  (Time-series) |
+----------------+     +----------------+     +----------------+
                               |
                               v
                       +----------------+
                       |                |
                       |  Binance API   |
                       |                |
                       +----------------+
```

## 4. Database Schema Design

### Strategy Schema
```elixir
defmodule Central.Backtest.Schema.Strategy do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "strategies" do
    field :name, :string
    field :description, :text
    field :config, :map        # JSON configuration
    field :entry_rules, :map   # Entry conditions
    field :exit_rules, :map    # Exit conditions
    field :is_active, :boolean, default: true
    field :is_public, :boolean, default: false
    
    belongs_to :user, Central.Accounts.User
    has_many :backtests, Central.Backtest.Schema.Backtest
    timestamps()
  end
  
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:name, :description, :config, :entry_rules, :exit_rules, :is_active, :is_public, :user_id])
    |> validate_required([:name, :config, :entry_rules, :exit_rules, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
```

### Backtest Schema
```elixir
defmodule Central.Backtest.Schema.Backtest do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "backtests" do
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :symbol, :string
    field :timeframe, :string
    field :initial_balance, :decimal
    field :final_balance, :decimal
    field :status, Ecto.Enum, values: [:pending, :running, :completed, :failed]
    field :metadata, :map
    
    belongs_to :strategy, Central.Backtest.Schema.Strategy
    belongs_to :user, Central.Accounts.User
    has_many :trades, Central.Backtest.Schema.Trade
    has_one :performance_summary, Central.Backtest.Schema.PerformanceSummary
    timestamps()
  end
  
  def changeset(backtest, attrs) do
    backtest
    |> cast(attrs, [:start_time, :end_time, :symbol, :timeframe, :initial_balance, :final_balance, :status, :metadata, :strategy_id, :user_id])
    |> validate_required([:start_time, :end_time, :symbol, :timeframe, :initial_balance, :status, :strategy_id, :user_id])
    |> foreign_key_constraint(:strategy_id)
    |> foreign_key_constraint(:user_id)
  end
end
```

### Trade Schema
```elixir
defmodule Central.Backtest.Schema.Trade do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "trades" do
    field :entry_time, :utc_datetime
    field :entry_price, :decimal
    field :exit_time, :utc_datetime
    field :exit_price, :decimal
    field :quantity, :decimal
    field :side, Ecto.Enum, values: [:long, :short]
    field :pnl, :decimal
    field :pnl_percentage, :decimal
    field :fees, :decimal
    field :tags, {:array, :string}
    field :entry_reason, :string
    field :exit_reason, :string
    field :metadata, :map
    
    belongs_to :backtest, Central.Backtest.Schema.Backtest
    timestamps()
  end
  
  def changeset(trade, attrs) do
    trade
    |> cast(attrs, [:entry_time, :entry_price, :exit_time, :exit_price, :quantity, :side, :pnl, :pnl_percentage, :fees, :tags, :entry_reason, :exit_reason, :metadata, :backtest_id])
    |> validate_required([:entry_time, :entry_price, :quantity, :side, :backtest_id])
    |> foreign_key_constraint(:backtest_id)
  end
end
```

### MarketData Schema
```elixir
defmodule Central.Backtest.Schema.MarketData do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "market_data" do
    field :symbol, :string
    field :timeframe, :string
    field :timestamp, :utc_datetime
    field :open, :decimal
    field :high, :decimal
    field :low, :decimal
    field :close, :decimal
    field :volume, :decimal
    field :source, :string, default: "binance"
    
    timestamps(updated_at: false)
    
    index [:symbol, :timeframe, :timestamp]
    index [:symbol, :timeframe, :source]
  end
  
  def changeset(market_data, attrs) do
    market_data
    |> cast(attrs, [:symbol, :timeframe, :timestamp, :open, :high, :low, :close, :volume, :source])
    |> validate_required([:symbol, :timeframe, :timestamp, :open, :high, :low, :close])
    |> unique_constraint([:symbol, :timeframe, :timestamp, :source])
  end
end
```

### TransactionHistory Schema (New)
```elixir
defmodule Central.Backtest.Schema.TransactionHistory do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "transaction_histories" do
    field :transaction_time, :utc_datetime
    field :symbol, :string
    field :price, :decimal
    field :quantity, :decimal
    field :side, Ecto.Enum, values: [:buy, :sell]
    field :transaction_type, Ecto.Enum, values: [:market, :limit, :stop_limit, :take_profit]
    field :transaction_id, :string
    field :exchange, :string
    field :metadata, :map
    field :is_replayed, :boolean, default: false
    
    belongs_to :user, Central.Accounts.User
    has_many :replay_executions, Central.Backtest.Schema.ReplayExecution
    timestamps()
  end
  
  def changeset(transaction_history, attrs) do
    transaction_history
    |> cast(attrs, [:transaction_time, :symbol, :price, :quantity, :side, :transaction_type, :transaction_id, :exchange, :metadata, :is_replayed, :user_id])
    |> validate_required([:transaction_time, :symbol, :price, :quantity, :side, :transaction_type, :exchange, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
```

### ReplayExecution Schema (New)
```elixir
defmodule Central.Backtest.Schema.ReplayExecution do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "replay_executions" do
    field :executed_at, :utc_datetime
    field :status, Ecto.Enum, values: [:pending, :completed, :failed]
    field :result, :map
    field :metadata, :map
    
    belongs_to :transaction_history, Central.Backtest.Schema.TransactionHistory
    belongs_to :backtest, Central.Backtest.Schema.Backtest
    timestamps()
  end
  
  def changeset(replay_execution, attrs) do
    replay_execution
    |> cast(attrs, [:executed_at, :status, :result, :metadata, :transaction_history_id, :backtest_id])
    |> validate_required([:executed_at, :status, :transaction_history_id, :backtest_id])
    |> foreign_key_constraint(:transaction_history_id)
    |> foreign_key_constraint(:backtest_id)
  end
end
```

### PerformanceSummary Schema (New)
```elixir
defmodule Central.Backtest.Schema.PerformanceSummary do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "performance_summaries" do
    field :total_trades, :integer
    field :winning_trades, :integer
    field :losing_trades, :integer
    field :win_rate, :decimal
    field :profit_factor, :decimal
    field :max_drawdown, :decimal
    field :max_drawdown_percentage, :decimal
    field :sharpe_ratio, :decimal
    field :sortino_ratio, :decimal
    field :total_pnl, :decimal
    field :total_pnl_percentage, :decimal
    field :average_win, :decimal
    field :average_loss, :decimal
    field :largest_win, :decimal
    field :largest_loss, :decimal
    field :metrics, :map
    
    belongs_to :backtest, Central.Backtest.Schema.Backtest
    timestamps()
  end
  
  def changeset(performance_summary, attrs) do
    performance_summary
    |> cast(attrs, [:total_trades, :winning_trades, :losing_trades, :win_rate, :profit_factor, :max_drawdown, 
                    :max_drawdown_percentage, :sharpe_ratio, :sortino_ratio, :total_pnl, :total_pnl_percentage, 
                    :average_win, :average_loss, :largest_win, :largest_loss, :metrics, :backtest_id])
    |> validate_required([:total_trades, :winning_trades, :losing_trades, :backtest_id])
    |> foreign_key_constraint(:backtest_id)
  end
end
```

## 5. Binance Integration

### Data Fetching Strategy

1. **Historical Data**
   - Use Binance REST API for historical kline data
   - Implement rate limiting and chunked requests
   - Store data in local database for faster backtest execution
   
```elixir
defmodule Central.Backtest.Services.Binance.Historical do
  def fetch_historical_data(symbol, timeframe, start_time, end_time) do
    # Chunk requests to handle rate limits
    chunks = chunk_time_range(start_time, end_time)
    
    chunks
    |> Task.async_stream(&fetch_chunk(symbol, timeframe, &1), max_concurrency: 2)
    |> Enum.reduce([], &process_chunk/2)
  end
  
  defp fetch_chunk(symbol, timeframe, {chunk_start, chunk_end}) do
    # Add exponential backoff and error handling
    with {:ok, response} <- BinanceClient.get_klines(symbol, timeframe, chunk_start, chunk_end),
         {:ok, data} <- process_response(response) do
      {:ok, data}
    else
      {:error, reason} -> handle_error(reason)
    end
  end
end
```

2. **Real-time Data**
   - WebSocket connection for live market data
   - Implement reconnection logic and heartbeat monitoring
   
```elixir
defmodule Central.Backtest.Services.Binance.Stream do
  use GenServer
  
  def start_link(symbol) do
    GenServer.start_link(__MODULE__, symbol, name: via_tuple(symbol))
  end
  
  def init(symbol) do
    # Setup WebSocket connection
    {:ok, conn} = connect_websocket(symbol)
    
    state = %{
      symbol: symbol,
      connection: conn,
      subscribers: []
    }
    
    schedule_heartbeat()
    {:ok, state}
  end
  
  def handle_info(:heartbeat, state) do
    # Monitor connection health
    case check_connection(state.connection) do
      :ok -> 
        schedule_heartbeat()
        {:noreply, state}
      :error ->
        {:ok, conn} = reconnect(state.symbol)
        {:noreply, %{state | connection: conn}}
    end
  end
end
```

### Binance API Configuration
```elixir
# config/config.exs
config :central, Central.Backtest.Services.Binance,
  base_url: "https://api.binance.com",
  stream_url: "wss://stream.binance.com:9443/ws",
  rate_limit_rules: [
    {weight_per_minute: 1200, burst: 50},
    {orders_per_second: 5, burst: 10},
    {orders_per_day: 100000}
  ],
  retry_options: [
    max_attempts: 3,
    base_backoff_ms: 1000,
    max_backoff_ms: 5000
  ]
```

## 6. Core Backtest Components
This section outlines the key modules involved in the backtesting logic itself.

*   **Contexts:** Manage business logic (`strategy.ex`, `execution.ex`, `analysis.ex`).
*   **Services:** Handle external interactions and complex logic (`binance/`, `data_processor.ex`, `performance.ex`).
*   **Validators:** Ensure strategy rules and positions are valid (`rule_validator.ex`, `position_validator.ex`).
*   **Indicators:** Calculate technical indicators (`moving_average.ex`, `rsi.ex`, `macd.ex`).
*   **Risk Management:** Calculate position sizes and manage risk (`position_sizer.ex`, `risk_calculator.ex`).
*   **Reporting:** Generate performance metrics and reports (`metrics.ex`, `report_generator.ex`).
*   **Workers:** Handle background tasks (`market_sync.ex`, `backtest_runner.ex`).

## 7. Transaction Replay System

1. **Import & Storage**
   - Import transactions from CSV or exchange API
   - Normalize and store in `transaction_histories` table
   - Associate with user account

2. **Replay Mechanism**
   ```elixir
   defmodule Central.Backtest.Services.TransactionReplay do
     alias Central.Backtest.Schema.{TransactionHistory, ReplayExecution}
     alias Central.Repo
     
     def replay_transaction(transaction_id, backtest_id) do
       transaction = Repo.get!(TransactionHistory, transaction_id)
       backtest = Repo.get!(Backtest, backtest_id)
       
       # Create replay execution record
       execution = %ReplayExecution{
         executed_at: DateTime.utc_now(),
         status: :pending,
         transaction_history_id: transaction.id,
         backtest_id: backtest.id
       }
       |> Repo.insert!()
       
       # Queue the actual replay job
       Central.Backtest.Workers.TransactionReplayWorker.perform_async(%{
         "execution_id" => execution.id
       })
       
       {:ok, execution}
     end
     
     def process_replay(execution_id) do
       execution = Repo.get!(ReplayExecution, execution_id) |> Repo.preload([:transaction_history, :backtest])
       
       # Execute the transaction in the context of the backtest
       result = execute_transaction_in_backtest(execution.transaction_history, execution.backtest)
       
       # Update the execution record with results
       execution
       |> Ecto.Changeset.change(%{
         status: :completed,
         result: result
       })
       |> Repo.update!()
     end
     
     defp execute_transaction_in_backtest(transaction, backtest) do
       # Implementation would depend on the backtest engine
       # This would apply the transaction at the historical time point
       # and calculate the outcome
     end
   end
   ```

3. **User Interface Integration**
   - Allow selection of historical transactions
   - Provide replay options (single transaction vs batch)
   - Visualize original vs replayed results

## 8. User Interface & Experience

### LiveView Structure
*   **Backtest Management:** `strategy_live.ex`, `execution_live.ex`, `results_live.ex`
*   **Components:** `strategy_form_component.ex`, `trade_table_component.ex`, `performance_metrics_component.ex`, `chart_controls_component.ex`, `chart_component.ex`, `trade_list.ex`
*   **Shared Components:** `modal_component.ex`, `notification_component.ex`

### Assets & Hooks
*   **JavaScript Hooks:** `tradingview_chart.js`, `strategy_editor.js`, `backtest_controls.js`
*   **Libraries:** `trading_indicators.js`
*   **CSS:** `app.css`, `charts.css`

### User Experience Considerations
1. **Realtime Feedback**
   - Live chart updates during backtest
   - Progress indicators for long-running operations
   - Interactive parameter adjustments

2. **Data Visualization**
   - Customizable chart indicators
   - Trade entry/exit markers on chart
   - Performance metrics dashboards

3. **Mobile Responsiveness**
   - Responsive layout for all screens
   - Touch-friendly interactions
   - Progressive web app capabilities

## 9. Performance & Scalability

1. **Data Storage Optimization**
   - Implement partitioning for `market_data` table by symbol and time range (using TimescaleDB hypertables is recommended).
   - Use materialized views for commonly accessed aggregations.
   - Consider using TimescaleDB for time-series optimization.

2. **Caching Strategy**
   - Cache frequently accessed market data in ETS tables.
   - Implement LRU cache for backtest results.
   - Use Redis for distributed caching if needed.

3. **Concurrent Processing**
   - Use `Task.async_stream` for parallel operations (e.g., historical data fetching).
   - Implement job queuing for long-running backtests (e.g., using Oban or GenServer-based queue).
   - Consider using Broadway for high-throughput stream processing if needed.

## 10. Integration Patterns & API Design

1. **Event-Driven Architecture**
   - Use `Phoenix.PubSub` for real-time updates within the application (e.g., backtest status).
   - Implement event streams for market data processing stages.
   - Design event handlers for decoupling strategy execution steps.

2. **API Design**
   - **Internal RESTful API:** For managing backtest resources (strategies, backtests, results).
     ```elixir
     # lib/central_web/router.ex
     scope "/api", CentralWeb do
       pipe_through [:api, :api_auth] # Ensure proper authentication

       resources "/strategies", StrategyController, except: [:new, :edit]
       resources "/backtests", BacktestController, except: [:new, :edit]
       post "/backtests/:id/replay", BacktestController, :replay

       scope "/market_data" do
         get "/symbols", MarketDataController, :list_symbols
         get "/:symbol/:timeframe", MarketDataController, :get_candles
       end

       scope "/transactions" do
         resources "/history", TransactionHistoryController, except: [:new, :edit]
         post "/history/:id/replay", TransactionHistoryController, :replay
         get "/summary", TransactionHistoryController, :summary
       end
     end
     ```
   - **WebSocket API:** For real-time communication (market data, backtest progress, chart updates).
     ```elixir
     # lib/central_web/channels/user_socket.ex
     defmodule CentralWeb.UserSocket do
       use Phoenix.Socket

       # Channels for different real-time features
       channel "chart:*", CentralWeb.ChartChannel
       channel "backtest:*", CentralWeb.BacktestChannel
       channel "market:*", CentralWeb.MarketChannel # For live market data stream

       @impl true
       def connect(%{"token" => token}, socket, _connect_info) do
         # Verify user token for secure connection
         case Phoenix.Token.verify(CentralWeb.Endpoint, "user socket", token, max_age: 86400) do
           {:ok, user_id} ->
             {:ok, assign(socket, :user_id, user_id)}
           {:error, _reason} ->
             :error
         end
       end

       # Identifies the socket connection
       @impl true
       def id(socket), do: "user_socket:#{socket.assigns.user_id}"
     end
     ```

3. **External Integrations**
   - Binance API integration (detailed in Section 5).
   - TradingView webhook support (potential future feature).
   - Notification services (Email, Telegram) for alerts or results.

## 11. Security Considerations

1. **Authentication & Authorization**
   - Use a robust authentication library (e.g., `Pow`, `Guardian`). Phoenix.Token shown for basic API/WebSocket auth.
   - Implement Role-Based Access Control (RBAC) to restrict access based on user roles.
   - Enforce user data isolation for strategies and backtests.
   ```elixir
   # Example using Guardian for token-based auth
   defmodule Central.Accounts.Guardian do
     use Guardian, otp_app: :central
     
     def subject_for_token(user, _claims) do
       {:ok, to_string(user.id)}
     end
     
     def resource_from_claims(%{"sub" => id}) do
       user = Central.Accounts.get_user!(id) # Fetch user from database
       {:ok, user}
     rescue
       Ecto.NoResultsError -> {:error, :resource_not_found}
     end
   end
   ```

2. **API Security**
   - Implement rate limiting for API endpoints to prevent abuse.
   - Use SSL/TLS (HTTPS) for all communications.
   - Store sensitive API keys (e.g., user's Binance keys) securely using encryption (e.g., using `cloak_ecto` or a dedicated vault solution).
   ```elixir
   # Example concept for secure key storage
   defmodule Central.Backtest.Services.ApiKeyManager do
     alias Central.Vault # Assumes a Vault module for encryption/decryption

     def store_binance_credentials(user_id, api_key, api_secret) do
       # Encrypt and store securely, associated with user_id
       Vault.encrypt_and_store("binance_keys:#{user_id}", %{
         api_key: api_key,
         api_secret: api_secret
       })
     end
     
     def get_binance_credentials(user_id) do
       # Retrieve and decrypt
       case Vault.get_and_decrypt("binance_keys:#{user_id}") do
         {:ok, credentials} -> credentials
         {:error, _} -> nil # Handle errors appropriately
       end
     end
   end
   ```

3. **Data Protection**
   - Encrypt sensitive user data at rest where appropriate.
   - Implement regular database backups and a recovery plan.
   - Use parameterized queries (standard with Ecto) to prevent SQL injection.
   ```elixir
   # Ecto queries are inherently parameterized
   def get_user_strategies(user_id) do
     from(s in Central.Backtest.Schema.Strategy,
       where: s.user_id == ^user_id and s.is_active == true
     )
     |> Central.Repo.all()
   end
   ```

## 12. Infrastructure & DevOps

1. **Docker Configuration**
   - Use multi-stage builds for smaller, secure production images.
   - Implement health checks for container orchestration.
   - Configure appropriate resource limits.
   ```dockerfile
   # Example Production Dockerfile
   FROM elixir:1.17-alpine AS builder # <-- Updated Elixir version

   # Install build dependencies
   RUN apk add --no-cache build-base npm git python3

   WORKDIR /app

   # Install hex + rebar
   RUN mix local.hex --force && \
       mix local.rebar --force

   ENV MIX_ENV=prod

   # Install mix dependencies
   COPY mix.exs mix.lock ./
   COPY config config
   RUN mix deps.get --only prod
   RUN mix deps.compile

   # Build assets
   COPY assets assets
   WORKDIR /app/assets
   RUN npm ci && npm run deploy # Assumes deploy script in package.json
   WORKDIR /app
   RUN mix phx.digest

   # Compile and build release
   COPY lib lib
   COPY priv priv # Include priv directory if needed in release
   RUN mix compile --force
   RUN mix release

   # --- Release Stage ---
   FROM alpine:3.18 AS app # Use a recent Alpine version

   # Install runtime dependencies
   RUN apk add --no-cache openssl ncurses-libs libstdc++

   WORKDIR /app
   RUN chown nobody:nobody /app
   USER nobody:nobody

   # Copy the built release from the builder stage
   COPY --from=builder --chown=nobody:nobody /app/_build/prod/rel/central ./

   ENV HOME=/app
   ENV PORT=4000
   ENV PHX_SERVER=true

   EXPOSE 4000

   # Basic health check
   HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
     CMD wget --quiet --tries=1 --spider http://localhost:4000/api/health || exit 1 # Adjust URL as needed

   CMD ["/app/bin/server"] # Start the Phoenix server
   ```

2. **Kubernetes Setup (Example)**
   - Implement auto-scaling based on application load.
   - Configure persistent volumes for database storage.
   - Use Kubernetes secrets for managing sensitive configuration (DB URLs, API keys, `SECRET_KEY_BASE`).
   ```yaml
   # Example Kubernetes Deployment Snippet
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: central-backtest
   spec:
     replicas: 2 # Start with 2 replicas
     selector:
       matchLabels:
         app: central-backtest
     template:
       metadata:
         labels:
           app: central-backtest
       spec:
         containers:
         - name: central-backtest
           image: your-registry/central-backtest:latest # Replace with your image
           ports:
           - containerPort: 4000
           resources: # Define resource requests and limits
             limits:
               cpu: "1"
               memory: "1Gi"
             requests:
               cpu: "500m"
               memory: "512Mi"
            env: # Load sensitive config from secrets
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: central-secrets
                  key: database-url
            - name: SECRET_KEY_BASE
              valueFrom:
                secretKeyRef:
                  name: central-secrets
                  key: secret-key-base
            readinessProbe: # Check if app is ready to serve traffic
              httpGet:
                path: /api/health # Use the health check endpoint
                port: 4000
              initialDelaySeconds: 10
              periodSeconds: 15
            livenessProbe: # Check if app is still alive
              httpGet:
                path: /api/health
                port: 4000
              initialDelaySeconds: 20
              periodSeconds: 30
   ```

3. **Monitoring and Maintenance**
   - **Metrics:** Track API rate limit usage, database query performance, backtest execution time, memory/CPU usage. Use `Telemetry.Metrics` and reporters (`Telemetry.Metrics.Prometheus`, etc.).
   - **Alerting:** Set up alerts for API failures, high error rates, database performance degradation, and system resource exhaustion (using tools like Prometheus Alertmanager or Grafana Alerting).
   - **Maintenance:** Implement regular database cleanup/vacuuming, cache invalidation strategies, log rotation policies.

4. **CI/CD Pipeline**
   - Automate testing, building, and deployment.
   - Use tools like GitHub Actions, GitLab CI, Jenkins.
   - Include steps for dependency caching, running tests (unit, integration), code quality checks (Credo, Dialyzer), building releases/Docker images, and deploying to staging/production environments.

5. **Backup and Recovery**
   - Implement regular, automated backups of the PostgreSQL database.
   - Test the recovery process periodically.

## 13. Development & Testing

1. **Development Tools**
   *   Setup `mix` aliases for common tasks (`mix setup`, `mix test`, `mix format`).
   *   Configure code formatter (`mix format`) and linter (`mix credo`).
   *   Consider git hooks for pre-commit checks (formatting, linting).

2. **Testing Strategy**
   *   **Unit Tests:** For individual functions and modules (business logic, calculations). Use `ExUnit`.
   *   **Integration Tests:** For interactions between components (e.g., context functions interacting with the database, Binance API client).
   *   **Property-based Testing:** For validating functions against a wide range of inputs, especially for calculations and rule validation (`StreamData`).
   *   **End-to-end Tests:** For simulating user flows through the LiveView interface (e.g., using `Wallaby`).
   *   Use fixtures (`ExMachina`) for generating test data.
   *   Use mocks (e.g., `Mox`) for isolating external services like the Binance API during tests.

3. **Documentation**
   *   Write module documentation (`@moduledoc`, `@doc`). Generate documentation using `ExDoc`.
   *   Maintain API documentation (potentially using OpenAPI/Swagger for REST APIs).
   *   Create user guides for end-users.
   *   Consider Architecture Decision Records (ADRs) for significant design choices.

## 14. Next Steps

1. **Phase 1: Core Infrastructure**
   *   Set up database schemas and migrations
   *   Implement Binance API client
   *   Create basic market data synchronization

2. **Phase 2: Backtest Engine**
   *   Develop strategy execution engine
   *   Implement performance analytics
   *   Create basic visualization components

3. **Phase 3: User Interface**
   *   Build strategy configuration interface
   *   Develop interactive charting
   *   Create results dashboard

4. **Phase 4: Optimization**
   *   Add caching layers
   *   Implement parallel processing
   *   Optimize database queries
