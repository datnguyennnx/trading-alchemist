# Stage 4: Optimization and Scalability Implementation

## Overview
Building on the functional backtest system developed in Stages 1-3, this phase focuses on optimization, performance improvements, and scaling capabilities. We'll implement advanced caching mechanisms, parallel processing for backtests, and database optimizations to handle larger datasets efficiently.

## Implementation Focus

### 1. Database Optimization (Week 1)
- Implement database partitioning for market data
- Optimize query performance
- Create materialized views for frequent queries
- Configure proper indices for high-volume tables

**Priority Tasks:**
1. Implement TimescaleDB integration for market data
2. Create partitioning strategy for historical data
3. Optimize query patterns with targeted indices
4. Implement materialized views for performance metrics

```sql
-- Sample SQL for creating hypertable for market data with TimescaleDB
CREATE TABLE market_data (
  id BIGSERIAL PRIMARY KEY,
  symbol TEXT NOT NULL,
  timeframe TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  open DECIMAL(18,8) NOT NULL,
  high DECIMAL(18,8) NOT NULL,
  low DECIMAL(18,8) NOT NULL,
  close DECIMAL(18,8) NOT NULL,
  volume DECIMAL(24,8),
  source TEXT DEFAULT 'binance',
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Convert to TimescaleDB hypertable
SELECT create_hypertable('market_data', 'timestamp', chunk_time_interval => INTERVAL '1 day');

-- Create composite index for common query patterns
CREATE INDEX idx_market_data_symbol_timeframe_timestamp ON market_data (symbol, timeframe, timestamp DESC);

-- Create additional indices for performance
CREATE INDEX idx_market_data_source_symbol ON market_data (source, symbol);
```

```elixir
# Sample optimized queries for market data
defmodule Central.Backtest.Contexts.MarketData do
  import Ecto.Query
  alias Central.Repo
  alias Central.Backtest.Schema.MarketData
  
  def get_candles_optimized(symbol, timeframe, start_time, end_time) do
    from(m in MarketData,
      where: m.symbol == ^symbol and
             m.timeframe == ^timeframe and
             m.timestamp >= ^start_time and
             m.timestamp <= ^end_time,
      order_by: [asc: m.timestamp],
      select: %{
        time: m.timestamp,
        open: m.open,
        high: m.high,
        low: m.low,
        close: m.close,
        volume: m.volume
      }
    )
    |> Repo.all()
  end
  
  def get_latest_candle(symbol, timeframe) do
    from(m in MarketData,
      where: m.symbol == ^symbol and m.timeframe == ^timeframe,
      order_by: [desc: m.timestamp],
      limit: 1
    )
    |> Repo.one()
  end
  
  # Function to downsample data for larger timeframes
  def get_downsampled_candles(symbol, timeframe, start_time, end_time, max_points \\ 1000) do
    # Calculate required interval based on date range and max points
    total_seconds = DateTime.diff(end_time, start_time)
    interval_seconds = max(div(total_seconds, max_points), 60)
    
    # Using SQL for efficient downsampling
    # This example uses PostgreSQL time_bucket function from TimescaleDB
    query = """
    SELECT 
      time_bucket($1, timestamp) AS time_bucket,
      FIRST(open, timestamp) AS open,
      MAX(high) AS high,
      MIN(low) AS low,
      LAST(close, timestamp) AS close,
      SUM(volume) AS volume
    FROM market_data
    WHERE symbol = $2 AND timeframe = $3 AND timestamp BETWEEN $4 AND $5
    GROUP BY time_bucket
    ORDER BY time_bucket ASC
    """
    
    {:ok, result} = Repo.query(query, [
      "#{interval_seconds} seconds", 
      symbol, 
      timeframe, 
      start_time, 
      end_time
    ])
    
    Enum.map(result.rows, fn [time, open, high, low, close, volume] ->
      %{
        time: time,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume
      }
    end)
  end
end
```

### 2. Caching Implementation (Week 2)
- Set up multi-level caching system
- Implement in-memory caching with ETS
- Add Redis for distributed caching
- Create cache invalidation strategies

**Priority Tasks:**
1. Implement ETS-based caching for market data
2. Set up Redis for distributed cache
3. Create intelligent cache invalidation
4. Build cache warming mechanism

```elixir
# Sample cache implementation
defmodule Central.Backtest.Cache do
  use GenServer
  alias Central.Backtest.Contexts.MarketData
  
  @ets_table :market_data_cache
  @default_ttl 3600 # 1 hour in seconds
  
  # Client API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  def get_candles(symbol, timeframe, start_time, end_time) do
    cache_key = generate_key(symbol, timeframe, start_time, end_time)
    
    case lookup_cache(cache_key) do
      {:hit, data} -> 
        # Cache hit
        data
        
      :miss ->
        # Cache miss, fetch from database
        data = MarketData.get_candles_optimized(symbol, timeframe, start_time, end_time)
        store_cache(cache_key, data)
        data
    end
  end
  
  def invalidate(symbol, timeframe) do
    GenServer.cast(__MODULE__, {:invalidate, symbol, timeframe})
  end
  
  def warm_cache(symbols, timeframes) do
    GenServer.cast(__MODULE__, {:warm_cache, symbols, timeframes})
  end
  
  # Server callbacks
  
  def init(_) do
    :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end
  
  def handle_cast({:invalidate, symbol, timeframe}, state) do
    # Use pattern matching to delete all entries for this symbol/timeframe
    :ets.match_delete(@ets_table, {{symbol, timeframe, :_, :_}, :_})
    
    # Also invalidate in Redis if configured
    if Application.get_env(:central, :use_redis_cache) do
      Redix.command(:redix, ["DEL", "market_data:#{symbol}:#{timeframe}:*"])
    end
    
    {:noreply, state}
  end
  
  def handle_cast({:warm_cache, symbols, timeframes}, state) do
    # Get common time ranges
    now = DateTime.utc_now()
    ranges = [
      {DateTime.add(now, -1, :day), now},            # Last day
      {DateTime.add(now, -7, :day), now},            # Last week
      {DateTime.add(now, -30, :day), now}            # Last month
    ]
    
    # Warm cache in background
    Task.start(fn ->
      for symbol <- symbols,
          timeframe <- timeframes,
          {start_time, end_time} <- ranges do
        MarketData.get_candles_optimized(symbol, timeframe, start_time, end_time)
        |> store_cache(generate_key(symbol, timeframe, start_time, end_time))
      end
    end)
    
    {:noreply, state}
  end
  
  # Private functions
  
  defp generate_key(symbol, timeframe, start_time, end_time) do
    start_ts = DateTime.to_unix(start_time)
    end_ts = DateTime.to_unix(end_time)
    {symbol, timeframe, start_ts, end_ts}
  end
  
  defp lookup_cache(key) do
    case :ets.lookup(@ets_table, key) do
      [{^key, {data, expires_at}}] ->
        if :os.system_time(:seconds) < expires_at do
          {:hit, data}
        else
          :ets.delete(@ets_table, key)
          :miss
        end
        
      [] ->
        # Try Redis if configured
        if Application.get_env(:central, :use_redis_cache) do
          {symbol, timeframe, start_ts, end_ts} = key
          redis_key = "market_data:#{symbol}:#{timeframe}:#{start_ts}:#{end_ts}"
          
          case Redix.command(:redix, ["GET", redis_key]) do
            {:ok, nil} -> :miss
            {:ok, data} -> {:hit, Jason.decode!(data)}
            _ -> :miss
          end
        else
          :miss
        end
    end
  end
  
  defp store_cache(key, data) do
    expires_at = :os.system_time(:seconds) + @default_ttl
    :ets.insert(@ets_table, {key, {data, expires_at}})
    
    # Also store in Redis if configured
    if Application.get_env(:central, :use_redis_cache) do
      {symbol, timeframe, start_ts, end_ts} = key
      redis_key = "market_data:#{symbol}:#{timeframe}:#{start_ts}:#{end_ts}"
      
      Redix.command(:redix, ["SET", redis_key, Jason.encode!(data), "EX", @default_ttl])
    end
    
    data
  end
end
```

### 3. Parallel Processing (Week 3)
- Implement parallel backtest execution
- Create job queuing system for backtests
- Develop concurrent data processing
- Build distributed workload management

**Priority Tasks:**
1. Implement job queue for backtest execution
2. Create parallel strategy execution
3. Develop supervisor for managing backtest workers
4. Build monitoring system for execution status

```elixir
# Sample job queue for backtest execution
defmodule Central.Backtest.Workers.BacktestQueue do
  use GenServer
  alias Central.Backtest.Workers.BacktestRunner
  alias Central.Backtest.Contexts.Backtest
  
  @max_concurrent_jobs 5
  
  # Client API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  def enqueue(backtest_id, options \\ []) do
    GenServer.call(__MODULE__, {:enqueue, backtest_id, options})
  end
  
  def status do
    GenServer.call(__MODULE__, :status)
  end
  
  # Server callbacks
  
  def init(_) do
    state = %{
      queue: :queue.new(),
      running: %{},  # Map of backtest_id => pid
      max_concurrent: @max_concurrent_jobs
    }
    
    {:ok, state}
  end
  
  def handle_call({:enqueue, backtest_id, options}, _from, state) do
    # Check if the backtest is already running or queued
    if Map.has_key?(state.running, backtest_id) or is_queued?(state.queue, backtest_id) do
      {:reply, {:error, :already_queued}, state}
    else
      # Update backtest status to pending
      Backtest.update_status(backtest_id, :pending)
      
      # Either start immediately or enqueue based on capacity
      if map_size(state.running) < state.max_concurrent do
        {:ok, pid} = start_backtest(backtest_id, options)
        new_running = Map.put(state.running, backtest_id, pid)
        
        {:reply, {:ok, :started}, %{state | running: new_running}}
      else
        new_queue = :queue.in({backtest_id, options}, state.queue)
        
        {:reply, {:ok, :queued}, %{state | queue: new_queue}}
      end
    end
  end
  
  def handle_call(:status, _from, state) do
    status = %{
      running: map_size(state.running),
      queued: :queue.len(state.queue),
      max_concurrent: state.max_concurrent
    }
    
    {:reply, status, state}
  end
  
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Find which backtest this process was running
    {backtest_id, running} = 
      Enum.find_value(state.running, {nil, state.running}, fn {id, runner_pid} ->
        if runner_pid == pid, do: {id, Map.delete(state.running, id)}, else: nil
      end)
    
    # Start next backtest from queue if available
    {new_queue, new_running} =
      case :queue.out(state.queue) do
        {{:value, {next_id, options}}, rest} ->
          {:ok, new_pid} = start_backtest(next_id, options)
          {rest, Map.put(running, next_id, new_pid)}
          
        {:empty, _} ->
          {state.queue, running}
      end
    
    {:noreply, %{state | queue: new_queue, running: new_running}}
  end
  
  # Private functions
  
  defp start_backtest(backtest_id, options) do
    # Start a BacktestRunner process and monitor it
    {:ok, pid} = BacktestRunner.start_link(backtest_id: backtest_id, options: options)
    Process.monitor(pid)
    {:ok, pid}
  end
  
  defp is_queued?(queue, backtest_id) do
    :queue.filter(fn {id, _} -> id == backtest_id end, queue) != :queue.new()
  end
end

# Sample backtest runner process
defmodule Central.Backtest.Workers.BacktestRunner do
  use GenServer
  alias Central.Backtest.Services.StrategyExecutor
  alias Central.Backtest.Contexts.Backtest
  alias Central.Backtest.Services.Performance
  alias Phoenix.PubSub
  
  # Client API
  
  def start_link(args) do
    backtest_id = Keyword.fetch!(args, :backtest_id)
    GenServer.start_link(__MODULE__, args, name: via_tuple(backtest_id))
  end
  
  # Server callbacks
  
  def init(args) do
    backtest_id = Keyword.fetch!(args, :backtest_id)
    options = Keyword.get(args, :options, [])
    
    # Start execution in handle_continue to not block start_link
    {:ok, %{backtest_id: backtest_id, options: options}, {:continue, :execute}}
  end
  
  def handle_continue(:execute, %{backtest_id: backtest_id, options: options} = state) do
    # Update status to running
    Backtest.update_status(backtest_id, :running)
    
    # Broadcast update
    PubSub.broadcast(Central.PubSub, "backtest:#{backtest_id}", {:backtest_status, :running})
    
    # Execute backtest
    case StrategyExecutor.execute_backtest(backtest_id, options) do
      {:ok, result} ->
        # Generate performance summary
        Performance.generate_performance_summary(backtest_id)
        
        # Update status to completed
        backtest = Backtest.update_status(backtest_id, :completed)
        
        # Broadcast completion
        PubSub.broadcast(Central.PubSub, "backtest:#{backtest_id}", {:backtest_update, backtest})
        
      {:error, reason} ->
        # Update status to failed
        backtest = Backtest.update_status(backtest_id, :failed, %{error: reason})
        
        # Broadcast failure
        PubSub.broadcast(Central.PubSub, "backtest:#{backtest_id}", {:backtest_error, backtest})
    end
    
    # Process can terminate after execution
    {:stop, :normal, state}
  end
  
  # Private functions
  
  defp via_tuple(backtest_id) do
    {:via, Registry, {Central.Backtest.Registry, {__MODULE__, backtest_id}}}
  end
end
```

### 4. Performance Monitoring and Tuning (Week 4)
- Implement system monitoring
- Create performance logging and metrics
- Build analysis tools for bottlenecks
- Develop automatic tuning mechanisms

**Priority Tasks:**
1. Set up monitoring for database queries
2. Implement logging for backtest execution times
3. Create dashboard for system performance
4. Develop automatic index suggestions

```elixir
# Sample performance monitoring module
defmodule Central.Backtest.Services.PerformanceMonitor do
  use GenServer
  require Logger
  alias Central.Repo
  
  # Client API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  def record_operation(operation, start_time, end_time, metadata \\ %{}) do
    duration_ms = DateTime.diff(end_time, start_time, :millisecond)
    GenServer.cast(__MODULE__, {:record, operation, duration_ms, metadata})
  end
  
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end
  
  # Server callbacks
  
  def init(_) do
    # Create ETS table for storing metrics
    :ets.new(:performance_metrics, [:named_table, :set, :public, write_concurrency: true])
    
    # Schedule periodic reporting
    schedule_report()
    
    # Schedule periodic database analysis
    schedule_db_analysis()
    
    {:ok, %{}}
  end
  
  def handle_cast({:record, operation, duration_ms, metadata}, state) do
    # Log slow operations
    if duration_ms > 1000 do
      Logger.warning("Slow operation: #{operation} took #{duration_ms}ms", metadata)
    end
    
    # Update metrics in ETS
    :ets.update_counter(:performance_metrics, {operation, :count}, {2, 1}, {{operation, :count}, 0})
    :ets.update_counter(:performance_metrics, {operation, :total_ms}, {2, duration_ms}, {{operation, :total_ms}, 0})
    
    # Update max duration if needed
    case :ets.lookup(:performance_metrics, {operation, :max_ms}) do
      [] -> 
        :ets.insert(:performance_metrics, {{operation, :max_ms}, duration_ms})
      [{{operation, :max_ms}, current_max}] when duration_ms > current_max ->
        :ets.insert(:performance_metrics, {{operation, :max_ms}, duration_ms})
      _ ->
        :ok
    end
    
    {:noreply, state}
  end
  
  def handle_call(:get_metrics, _from, state) do
    metrics = :ets.tab2list(:performance_metrics)
    |> Enum.reduce(%{}, fn
      {{operation, :count}, count}, acc ->
        put_in(acc, [operation, :count], count)
      {{operation, :total_ms}, total}, acc ->
        put_in(acc, [operation, :total_ms], total)
      {{operation, :max_ms}, max}, acc ->
        put_in(acc, [operation, :max_ms], max)
    end)
    |> Enum.map(fn {operation, stats} ->
      avg = if stats[:count] > 0, do: stats[:total_ms] / stats[:count], else: 0
      {operation, Map.put(stats, :avg_ms, avg)}
    end)
    |> Map.new()
    
    {:reply, metrics, state}
  end
  
  def handle_info(:report, state) do
    # Log current metrics
    metrics = get_metrics()
    
    Logger.info("Performance metrics: #{inspect metrics}")
    
    # Reschedule
    schedule_report()
    
    {:noreply, state}
  end
  
  def handle_info(:analyze_db, state) do
    # Analyze database performance
    analyze_db_performance()
    
    # Reschedule
    schedule_db_analysis()
    
    {:noreply, state}
  end
  
  # Private functions
  
  defp schedule_report do
    # Report every hour
    Process.send_after(self(), :report, 60 * 60 * 1000)
  end
  
  defp schedule_db_analysis do
    # Analyze database every day
    Process.send_after(self(), :analyze_db, 24 * 60 * 60 * 1000)
  end
  
  defp analyze_db_performance do
    # This would typically run EXPLAIN ANALYZE on common queries
    # and analyze index usage statistics
    
    # Example: Check for unused indices
    {:ok, result} = Repo.query("""
    SELECT
      indexrelname AS index_name,
      idx_scan AS index_scans,
      idx_tup_read AS tuples_read,
      idx_tup_fetch AS tuples_fetched
    FROM pg_stat_user_indexes
    WHERE idx_scan = 0
    ORDER BY relname, indexrelname;
    """)
    
    if length(result.rows) > 0 do
      Logger.warning("Unused indices detected: #{inspect result.rows}")
    end
    
    # Example: Check for tables that might need indices
    {:ok, result} = Repo.query("""
    SELECT
      relname AS table_name,
      seq_scan AS sequential_scans,
      seq_tup_read AS sequential_tuples_read,
      idx_scan AS index_scans,
      idx_tup_fetch AS index_tuples_fetched
    FROM pg_stat_user_tables
    WHERE seq_scan > 10 AND seq_scan > idx_scan
    ORDER BY seq_scan DESC;
    """)
    
    if length(result.rows) > 0 do
      Logger.warning("Tables with many sequential scans detected: #{inspect result.rows}")
    end
  end
end
```

## Testing Strategy
- Benchmark database query performance
- Stress test the system with large datasets
- Validate caching effectiveness
- Measure concurrent backtest execution performance

## Expected Deliverables
- Optimized database schema with proper indexing
- Multi-level caching system for market data
- Parallel backtest execution framework
- Performance monitoring and tuning tools
- Comprehensive benchmark results

## Next Steps
After completing Stage 4, we will have a high-performance, scalable backtest system. The next stage will focus on implementing the transaction replay system, enhancing security features, and finalizing the production deployment configuration. 