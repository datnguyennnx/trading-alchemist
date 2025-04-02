# Stage 5: Transaction Replay, Security, and Production Implementation

## Overview
In this final implementation stage, we'll complete the backtest system by adding the transaction replay system, enhancing security features, and preparing for production deployment. These components turn our system into a complete, secure, and production-ready application.

## Implementation Focus

### 1. Transaction Replay System (Week 1-2)
- Implement transaction import and storage
- Create transaction replay mechanism
- Build comparison analytics
- Develop visualization for original vs. replayed transactions

**Priority Tasks:**
1. Create transaction import system (CSV, API)
2. Implement transaction storage and normalization
3. Build replay execution engine
4. Develop comparison analytics tools

```elixir
# Sample transaction import module
defmodule Central.Backtest.Services.TransactionImport do
  alias Central.Backtest.Schema.TransactionHistory
  alias Central.Repo
  
  def import_from_csv(file_path, user_id, options \\ []) do
    exchange = Keyword.get(options, :exchange, "binance")
    
    file_path
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Stream.map(fn row -> 
      # Transform CSV row to transaction struct
      # This depends on the CSV format - here's an example for a common format
      %{
        transaction_time: parse_timestamp(row["Time"]),
        symbol: normalize_symbol(row["Symbol"]),
        price: parse_decimal(row["Price"]),
        quantity: parse_decimal(row["Quantity"]),
        side: parse_side(row["Side"]),
        transaction_type: parse_type(row["Type"]),
        transaction_id: row["OrderID"] || UUID.uuid4(),
        exchange: exchange,
        metadata: %{
          "fee" => parse_decimal(row["Fee"] || "0"),
          "fee_asset" => row["FeeAsset"],
          "raw_data" => row
        },
        is_replayed: false,
        user_id: user_id
      }
    end)
    |> Stream.chunk_every(100) # Process in batches
    |> Stream.map(fn transactions ->
      Repo.insert_all(TransactionHistory, transactions, 
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:transaction_id, :exchange]
      )
    end)
    |> Enum.reduce({0, 0}, fn {inserted, _}, {total_inserted, total_chunks} ->
      {total_inserted + inserted, total_chunks + 1}
    end)
  end
  
  def import_from_binance(user_id, start_time, end_time) do
    # Get API credentials for the user
    credentials = Central.Backtest.Services.ApiKeyManager.get_binance_credentials(user_id)
    
    # Fetch transactions from Binance API
    case fetch_binance_transactions(credentials, start_time, end_time) do
      {:ok, transactions} ->
        # Transform and store transactions
        transformed = Enum.map(transactions, fn tx ->
          %{
            transaction_time: parse_binance_timestamp(tx["time"]),
            symbol: tx["symbol"],
            price: parse_decimal(tx["price"]),
            quantity: parse_decimal(tx["qty"]),
            side: parse_binance_side(tx["side"]),
            transaction_type: parse_binance_type(tx["type"]),
            transaction_id: tx["orderId"],
            exchange: "binance",
            metadata: %{
              "fee" => parse_decimal(tx["commission"] || "0"),
              "fee_asset" => tx["commissionAsset"],
              "raw_data" => tx
            },
            is_replayed: false,
            user_id: user_id
          }
        end)
        
        {count, _} = Repo.insert_all(TransactionHistory, transformed, 
          on_conflict: {:replace_all_except, [:id, :inserted_at]},
          conflict_target: [:transaction_id, :exchange]
        )
        
        {:ok, count}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Helper functions for parsing and normalizing data
  defp parse_timestamp(time_str) do
    # Parse timestamp based on format
    # Returns DateTime
  end
  
  defp normalize_symbol(symbol) do
    # Normalize symbol format
    String.upcase(symbol)
  end
  
  defp parse_decimal(value) do
    # Parse string to Decimal
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _ -> Decimal.new("0")
    end
  end
  
  defp parse_side("BUY"), do: :buy
  defp parse_side("SELL"), do: :sell
  defp parse_side(_), do: :buy
  
  defp parse_type("MARKET"), do: :market
  defp parse_type("LIMIT"), do: :limit
  defp parse_type("STOP_LIMIT"), do: :stop_limit
  defp parse_type("TAKE_PROFIT"), do: :take_profit
  defp parse_type(_), do: :market
  
  defp fetch_binance_transactions(credentials, start_time, end_time) do
    # Implement Binance API call to fetch transactions
    # Returns {:ok, transactions} or {:error, reason}
  end
end

# Sample transaction replay service
defmodule Central.Backtest.Services.TransactionReplay do
  alias Central.Backtest.Schema.{TransactionHistory, ReplayExecution, Backtest}
  alias Central.Backtest.Contexts.MarketData
  alias Central.Repo
  import Ecto.Query
  
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
  
  def replay_transactions(transaction_ids, backtest_id) do
    # Replay multiple transactions
    Enum.map(transaction_ids, fn id -> 
      replay_transaction(id, backtest_id)
    end)
    |> Enum.split_with(fn
      {:ok, _} -> true
      {:error, _} -> false
    end)
    |> then(fn {successes, failures} ->
      {:ok, length(successes), length(failures)}
    end)
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
    # Get market data for the time of the transaction
    window_start = DateTime.add(transaction.transaction_time, -3600, :second)
    window_end = DateTime.add(transaction.transaction_time, 3600, :second)
    
    market_data = MarketData.get_candles(
      transaction.symbol,
      backtest.timeframe,
      window_start,
      window_end
    )
    
    # Find the candle closest to the transaction time
    candle_at_transaction = find_closest_candle(market_data, transaction.transaction_time)
    
    # Calculate price difference between original transaction and current data
    price_diff = Decimal.sub(candle_at_transaction.close, transaction.price)
    price_diff_pct = Decimal.div(price_diff, transaction.price)
      |> Decimal.mult(Decimal.new(100))
    
    # Calculate potential P&L difference
    original_value = Decimal.mult(transaction.price, transaction.quantity)
    current_value = Decimal.mult(candle_at_transaction.close, transaction.quantity)
    pnl_diff = Decimal.sub(current_value, original_value)
    
    # Return comparison results
    %{
      original_price: transaction.price,
      replay_price: candle_at_transaction.close,
      price_diff: price_diff,
      price_diff_pct: price_diff_pct,
      pnl_diff: pnl_diff,
      candle_timestamp: candle_at_transaction.timestamp,
      candle_data: %{
        open: candle_at_transaction.open,
        high: candle_at_transaction.high,
        low: candle_at_transaction.low,
        close: candle_at_transaction.close,
        volume: candle_at_transaction.volume
      }
    }
  end
  
  defp find_closest_candle(candles, target_time) do
    # Find the candle with timestamp closest to target_time
    Enum.min_by(candles, fn candle -> 
      abs(DateTime.diff(candle.timestamp, target_time, :second))
    end)
  end
end
```

### 2. Security Enhancements (Week 3)
- Implement API key encryption
- Create role-based access control
- Set up secure authentication
- Develop audit logging system

**Priority Tasks:**
1. Implement secure API key management
2. Create role-based access control system
3. Add security hardening for APIs
4. Build comprehensive audit logging

```elixir
# Sample secure API key manager
defmodule Central.Backtest.Services.ApiKeyManager do
  alias Central.Vault
  alias Central.Accounts.User
  alias Central.Repo
  import Ecto.Query
  require Logger
  
  @vault_key "binance_keys"
  
  def store_binance_credentials(user_id, api_key, api_secret) do
    # Log audit event
    log_audit_event(user_id, "store_api_key", %{exchange: "binance"})
    
    # Generate a unique key for storing in the vault
    vault_key = "#{@vault_key}:#{user_id}"
    
    # Encrypt and store the credentials
    result = Vault.encrypt_and_store(vault_key, %{
      api_key: api_key,
      api_secret: api_secret,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    # Update user record to indicate they have Binance keys
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(set: [has_binance_api_key: true])
    
    result
  end
  
  def get_binance_credentials(user_id) do
    # Log audit event
    log_audit_event(user_id, "get_api_key", %{exchange: "binance"})
    
    # Retrieve and decrypt credentials
    vault_key = "#{@vault_key}:#{user_id}"
    
    case Vault.get_and_decrypt(vault_key) do
      {:ok, credentials} -> {:ok, credentials}
      {:error, :not_found} -> {:error, :no_credentials}
      {:error, reason} -> 
        Logger.error("Failed to retrieve API keys: #{inspect reason}")
        {:error, :retrieval_failed}
    end
  end
  
  def delete_binance_credentials(user_id) do
    # Log audit event
    log_audit_event(user_id, "delete_api_key", %{exchange: "binance"})
    
    # Delete from vault
    vault_key = "#{@vault_key}:#{user_id}"
    Vault.delete(vault_key)
    
    # Update user record
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(set: [has_binance_api_key: false])
    
    :ok
  end
  
  defp log_audit_event(user_id, action, metadata) do
    Central.Audit.log(%{
      user_id: user_id,
      action: action,
      resource_type: "api_key",
      metadata: metadata,
      ip_address: get_current_ip()
    })
  end
  
  defp get_current_ip do
    # In a real implementation, this would get the current user's IP
    # from the connection information
    "0.0.0.0"
  end
end

# Sample audit logging module
defmodule Central.Audit do
  alias Central.Repo
  alias Central.Audit.Log
  require Logger
  
  def log(attrs) do
    # Create the audit log entry
    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, log} -> {:ok, log}
      {:error, changeset} ->
        Logger.error("Failed to create audit log: #{inspect changeset.errors}")
        {:error, changeset}
    end
  end
  
  def get_logs_for_user(user_id, options \\ []) do
    import Ecto.Query
    
    limit = Keyword.get(options, :limit, 100)
    offset = Keyword.get(options, :offset, 0)
    
    from(l in Log,
      where: l.user_id == ^user_id,
      order_by: [desc: l.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end
  
  def get_logs_by_action(action, options \\ []) do
    import Ecto.Query
    
    limit = Keyword.get(options, :limit, 100)
    offset = Keyword.get(options, :offset, 0)
    
    from(l in Log,
      where: l.action == ^action,
      order_by: [desc: l.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end
end

# Sample RBAC plug
defmodule CentralWeb.Plugs.RBAC do
  import Plug.Conn
  import Phoenix.Controller
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    required_roles = Keyword.get(opts, :roles, [])
    resource_owner = Keyword.get(opts, :resource_owner)
    
    user = conn.assigns[:current_user]
    
    cond do
      # No user logged in
      is_nil(user) ->
        conn
        |> put_flash(:error, "You must be logged in to access this page")
        |> redirect(to: "/login")
        |> halt()
        
      # Check if user has required roles
      !has_required_roles?(user, required_roles) ->
        conn
        |> put_flash(:error, "You don't have permission to access this page")
        |> redirect(to: "/")
        |> halt()
        
      # Check resource ownership if specified
      !is_nil(resource_owner) && !check_resource_ownership(conn, user, resource_owner) ->
        conn
        |> put_flash(:error, "You don't have permission to access this resource")
        |> redirect(to: "/")
        |> halt()
        
      # All checks passed
      true ->
        conn
    end
  end
  
  defp has_required_roles?(user, required_roles) do
    # If no roles required, allow access
    if Enum.empty?(required_roles) do
      true
    else
      # Check if user has at least one of the required roles
      user_roles = MapSet.new(user.roles)
      required_set = MapSet.new(required_roles)
      
      !MapSet.disjoint?(user_roles, required_set)
    end
  end
  
  defp check_resource_ownership(conn, user, resource_owner) do
    # Extract resource ID from params
    resource_id = conn.params["id"]
    
    # Look up the resource and check ownership
    case apply(resource_owner.module, resource_owner.function, [resource_id]) do
      nil -> false
      resource -> resource.user_id == user.id
    end
  end
end
```

### 3. Production Deployment Configuration (Week 4)
- Prepare Docker and Kubernetes configuration
- Set up CI/CD pipeline
- Configure monitoring and alerting
- Develop backup and recovery strategy

**Priority Tasks:**
1. Create Docker and Kubernetes configuration
2. Set up CI/CD pipeline with GitHub Actions
3. Configure monitoring with Prometheus and Grafana
4. Implement backup and recovery strategy

```dockerfile
# Sample production Dockerfile
FROM elixir:1.14-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

# Prepare build directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod
RUN mix deps.compile

# Build assets
COPY assets assets
COPY priv priv
COPY lib lib
RUN cd assets && npm ci && npm run deploy
RUN mix phx.digest

# Compile and build release
RUN mix compile
RUN mix release

# Prepare release image
FROM alpine:3.16 AS app
RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=builder --chown=nobody:nobody /app/_build/prod/rel/central ./

ENV HOME=/app
ENV PORT=4000
ENV PHX_SERVER=true

EXPOSE 4000

# Add health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:4000/api/health || exit 1

CMD ["/app/bin/server"]
```

```yaml
# Sample Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: central-backtest
  labels:
    app: central-backtest
spec:
  replicas: 3
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
        image: registry.example.com/central-backtest:${TAG}
        ports:
        - containerPort: 4000
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: central-db-credentials
              key: url
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: central-secrets
              key: secret-key-base
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: central-redis-credentials
              key: url
        - name: LOG_LEVEL
          value: "info"
        resources:
          limits:
            cpu: "1"
            memory: "1Gi"
          requests:
            cpu: "500m"
            memory: "512Mi"
        readinessProbe:
          httpGet:
            path: /api/health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /api/health
            port: http
          initialDelaySeconds: 15
          periodSeconds: 20
      volumes:
      - name: tz-config
        configMap:
          name: timezone-config
---
apiVersion: v1
kind: Service
metadata:
  name: central-backtest
spec:
  selector:
    app: central-backtest
  ports:
  - port: 80
    targetPort: 4000
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: central-backtest
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - backtest.example.com
    secretName: backtest-tls
  rules:
  - host: backtest.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: central-backtest
            port:
              number: 80
```

```yaml
# Sample GitHub Actions CI/CD pipeline
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    name: Build and test
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: central_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.14.3'
        otp-version: '25.2'
    
    - name: Cache deps and build
      uses: actions/cache@v3
      with:
        path: |
          deps
          _build
        key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
        restore-keys: |
          ${{ runner.os }}-mix-
    
    - name: Install dependencies
      run: mix deps.get
    
    - name: Run tests
      run: mix test
      env:
        MIX_ENV: test
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/central_test
    
    - name: Run Credo
      run: mix credo
    
    - name: Run Dialyzer
      run: mix dialyzer

  deploy:
    name: Deploy to production
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to container registry
      uses: docker/login-action@v2
      with:
        registry: registry.example.com
        username: ${{ secrets.REGISTRY_USERNAME }}
        password: ${{ secrets.REGISTRY_PASSWORD }}
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v3
      with:
        push: true
        tags: registry.example.com/central-backtest:${{ github.sha }}
        build-args: |
          MIX_ENV=prod
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: v1.25.2
    
    - name: Set Kubernetes context
      uses: azure/k8s-set-context@v3
      with:
        kubeconfig: ${{ secrets.KUBE_CONFIG }}
    
    - name: Deploy to Kubernetes
      run: |
        sed -i "s/\${TAG}/${{ github.sha }}/g" k8s/deployment.yaml
        kubectl apply -f k8s/deployment.yaml
    
    - name: Verify deployment
      run: |
        kubectl rollout status deployment/central-backtest
```

### 4. Documentation and Finalization (Week 5)
- Create comprehensive user documentation
- Develop API documentation
- Write developer guides
- Implement system health checks

**Priority Tasks:**
1. Write user documentation and guides
2. Create API documentation
3. Implement system health checks
4. Conduct final system testing

```elixir
# Sample health check controller
defmodule CentralWeb.HealthController do
  use CentralWeb, :controller
  alias Central.Repo
  
  def check(conn, _params) do
    # Check database connection
    db_status = check_database()
    
    # Check Redis connection if configured
    redis_status = if Application.get_env(:central, :use_redis_cache) do
      check_redis()
    else
      :not_configured
    end
    
    # Check disk space
    disk_status = check_disk_space()
    
    # Overall status
    overall_status = 
      if db_status == :ok && (redis_status == :ok || redis_status == :not_configured) && 
         disk_status == :ok do
        :ok
      else
        :error
      end
    
    status_code = if overall_status == :ok, do: 200, else: 500
    
    conn
    |> put_status(status_code)
    |> json(%{
      status: overall_status,
      time: DateTime.utc_now(),
      services: %{
        database: db_status,
        redis: redis_status,
        disk: disk_status
      },
      version: Application.spec(:central, :vsn)
    })
  end
  
  defp check_database do
    try do
      Repo.query!("SELECT 1")
      :ok
    rescue
      _ -> :error
    end
  end
  
  defp check_redis do
    try do
      {:ok, "PONG"} = Redix.command(:redix, ["PING"])
      :ok
    rescue
      _ -> :error
    catch
      _, _ -> :error
    end
  end
  
  defp check_disk_space do
    # Check if disk usage is below 90%
    case System.cmd("df", ["-h", "."]) do
      {output, 0} ->
        usage = 
          output
          |> String.split("\n")
          |> Enum.at(1)
          |> String.split()
          |> Enum.at(4)
          |> String.replace("%", "")
          |> String.to_integer()
        
        if usage < 90, do: :ok, else: :warning
      _ ->
        :unknown
    end
  end
end
```

## Testing Strategy
- Conduct end-to-end testing of the transaction replay system
- Perform security audits and penetration testing
- Validate production configurations in staging environment
- Conduct load testing to verify scalability

## Expected Deliverables
- Complete transaction replay system
- Enhanced security features
- Production-ready deployment configuration
- Comprehensive documentation
- Final system testing results

## Next Steps
After completing this final implementation stage, the backtest system will be fully functional, secure, and ready for production deployment. The system will provide a complete solution for strategy backtesting and transaction replay, delivering valuable insights to traders and financial analysts. 