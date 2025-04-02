# Backtest System - Comprehensive Sequence Diagrams

This document presents detailed sequence diagrams for the key processes in the Backtest System.

## 1. Market Data Synchronization Flow

This diagram illustrates how historical market data is fetched, processed, and stored in the system.

```mermaid
sequenceDiagram
    participant MarketSyncWorker as Market Sync Worker
    participant BinanceClient as Binance Client
    participant DataProcessor as Data Processor
    participant MarketDataContext as Market Data Context
    participant Cache as ETS/Redis Cache
    participant DB as PostgreSQL/TimescaleDB
    participant BinanceAPI as Binance API
    
    MarketSyncWorker->>MarketSyncWorker: Schedule sync for symbols/timeframes
    
    loop For each symbol/timeframe pair
        MarketSyncWorker->>MarketDataContext: Check last synced timestamp
        MarketDataContext->>DB: Query latest data point
        DB-->>MarketDataContext: Return latest timestamp
        
        MarketSyncWorker->>BinanceClient: fetch_historical_data(symbol, timeframe, last_timestamp, now)
        
        BinanceClient->>BinanceClient: Calculate time chunks (rate limit compliance)
        
        loop For each time chunk
            BinanceClient->>BinanceAPI: Request kline data
            BinanceAPI-->>BinanceClient: Return OHLCV data
            
            alt API Error
                BinanceClient->>BinanceClient: Apply exponential backoff
                BinanceClient->>BinanceAPI: Retry request
            end
        end
        
        BinanceClient-->>MarketSyncWorker: Return aggregated market data
        
        MarketSyncWorker->>DataProcessor: Process raw market data
        DataProcessor->>DataProcessor: Normalize and validate data
        DataProcessor-->>MarketSyncWorker: Return processed data
        
        MarketSyncWorker->>MarketDataContext: Store market data
        MarketDataContext->>DB: Insert into market_data hypertable
        
        MarketDataContext->>Cache: Invalidate/update cache for symbol/timeframe
        
        MarketSyncWorker->>MarketSyncWorker: Update sync status and log completion
    end
    
    MarketSyncWorker->>MarketSyncWorker: Schedule next sync
```

## 2. Complete Backtest Execution Flow

This diagram shows the detailed flow of a backtest execution, from strategy configuration to results analysis.

```mermaid
sequenceDiagram
    actor Trader
    participant WebUI as Phoenix LiveView UI
    participant StrategyContext as Strategy Context
    participant ExecutionContext as Execution Context
    participant BacktestRunner as Backtest Runner Worker
    participant MarketDataContext as Market Data Context
    participant StrategyExecutor as Strategy Executor
    participant IndicatorCalc as Indicator Calculator
    participant RiskManager as Risk Manager
    participant PerfCalc as Performance Calculator
    participant AnalysisContext as Analysis Context
    participant Cache as ETS/Redis Cache
    participant DB as PostgreSQL/TimescaleDB
    
    Trader->>WebUI: Configure strategy parameters
    WebUI->>StrategyContext: Create/update strategy
    StrategyContext->>DB: Store strategy configuration
    DB-->>StrategyContext: Confirm storage
    StrategyContext-->>WebUI: Return strategy ID
    
    Trader->>WebUI: Initiate backtest (symbol, timeframe, date range)
    WebUI->>ExecutionContext: Create backtest
    ExecutionContext->>DB: Store backtest record (pending status)
    DB-->>ExecutionContext: Confirm storage
    
    ExecutionContext->>BacktestRunner: Queue backtest job
    BacktestRunner-->>ExecutionContext: Acknowledge job
    ExecutionContext-->>WebUI: Return backtest ID and pending status
    WebUI-->>Trader: Display pending status and job ID
    
    BacktestRunner->>ExecutionContext: Start backtest execution
    ExecutionContext->>DB: Update backtest status to "running"
    
    BacktestRunner->>StrategyContext: Load strategy configuration
    StrategyContext->>DB: Fetch strategy
    DB-->>StrategyContext: Return strategy details
    StrategyContext-->>BacktestRunner: Return strategy configuration
    
    BacktestRunner->>MarketDataContext: Request historical data
    MarketDataContext->>Cache: Check for cached data
    
    alt Data in cache
        Cache-->>MarketDataContext: Return cached market data
    else Data not in cache
        MarketDataContext->>DB: Query market_data for symbol/timeframe/range
        DB-->>MarketDataContext: Return market data
        MarketDataContext->>Cache: Store in cache
    end
    
    MarketDataContext-->>BacktestRunner: Return historical market data
    
    BacktestRunner->>IndicatorCalc: Calculate technical indicators
    IndicatorCalc->>IndicatorCalc: Process indicators (MA, RSI, MACD, etc.)
    IndicatorCalc-->>BacktestRunner: Return calculated indicators
    
    BacktestRunner->>StrategyExecutor: Execute strategy against data
    
    loop For each candle/timeframe
        StrategyExecutor->>StrategyExecutor: Evaluate entry rules
        
        alt Entry condition met
            StrategyExecutor->>RiskManager: Calculate position size
            RiskManager-->>StrategyExecutor: Return position details
            StrategyExecutor->>StrategyExecutor: Generate entry trade
            StrategyExecutor->>BacktestRunner: Signal entry trade
            BacktestRunner->>DB: Store trade (entry only)
        end
        
        StrategyExecutor->>StrategyExecutor: Evaluate exit rules for open positions
        
        alt Exit condition met
            StrategyExecutor->>StrategyExecutor: Generate exit for position
            StrategyExecutor->>BacktestRunner: Signal exit trade
            BacktestRunner->>DB: Update trade with exit details
        end
    end
    
    StrategyExecutor-->>BacktestRunner: Return execution results
    
    BacktestRunner->>PerfCalc: Calculate performance metrics
    PerfCalc->>DB: Fetch all trades for backtest
    DB-->>PerfCalc: Return trades
    
    PerfCalc->>PerfCalc: Calculate metrics (win rate, profit factor, drawdown, etc.)
    PerfCalc-->>BacktestRunner: Return performance summary
    
    BacktestRunner->>AnalysisContext: Store performance summary
    AnalysisContext->>DB: Insert performance_summary record
    DB-->>AnalysisContext: Confirm storage
    
    BacktestRunner->>ExecutionContext: Complete backtest
    ExecutionContext->>DB: Update backtest status to "completed"
    DB-->>ExecutionContext: Confirm update
    
    ExecutionContext->>WebUI: Notify backtest completion (via PubSub)
    WebUI-->>Trader: Update UI with completion status
    
    Trader->>WebUI: View backtest results
    WebUI->>AnalysisContext: Fetch performance data
    AnalysisContext->>DB: Query performance_summary
    DB-->>AnalysisContext: Return metrics
    AnalysisContext-->>WebUI: Return formatted results
    
    WebUI->>ExecutionContext: Fetch trade list
    ExecutionContext->>DB: Query trades for backtest
    DB-->>ExecutionContext: Return trade details
    ExecutionContext-->>WebUI: Return trade list
    
    WebUI-->>Trader: Display performance metrics and trades
```

## 3. Transaction Replay Flow

This diagram shows how historical transactions are imported and replayed in the system.

```mermaid
sequenceDiagram
    actor Trader
    participant WebUI as Phoenix LiveView UI
    participant TransactionContext as Transaction Context
    participant ImportService as Import Service
    participant ReplayWorker as Replay Worker
    participant ExecutionContext as Execution Context
    participant MarketDataContext as Market Data Context
    participant AnalysisContext as Analysis Context
    participant DB as PostgreSQL Database
    
    Trader->>WebUI: Upload transaction history file
    WebUI->>ImportService: Parse and import transactions
    ImportService->>ImportService: Validate and normalize data
    
    loop For each transaction
        ImportService->>TransactionContext: Store transaction
        TransactionContext->>DB: Insert transaction_history record
        DB-->>TransactionContext: Confirm storage
    end
    
    ImportService-->>WebUI: Return import summary
    WebUI-->>Trader: Display imported transactions
    
    Trader->>WebUI: Select transactions for replay
    Trader->>WebUI: Configure replay parameters
    WebUI->>ExecutionContext: Create backtest record for replay
    ExecutionContext->>DB: Store backtest (replay type)
    DB-->>ExecutionContext: Return backtest ID
    
    loop For each selected transaction
        WebUI->>TransactionContext: Request transaction replay
        TransactionContext->>DB: Create replay_execution record (pending)
        DB-->>TransactionContext: Return execution ID
        
        TransactionContext->>ReplayWorker: Queue replay job
        ReplayWorker-->>TransactionContext: Acknowledge job
    end
    
    TransactionContext-->>WebUI: Return replay job IDs
    WebUI-->>Trader: Display pending replay status
    
    loop For each replay job
        ReplayWorker->>TransactionContext: Load transaction details
        TransactionContext->>DB: Fetch transaction_history
        DB-->>TransactionContext: Return transaction
        TransactionContext-->>ReplayWorker: Return transaction details
        
        ReplayWorker->>MarketDataContext: Request market data around transaction time
        MarketDataContext->>DB: Query market_data
        DB-->>MarketDataContext: Return market data
        MarketDataContext-->>ReplayWorker: Return market data
        
        ReplayWorker->>ReplayWorker: Replay transaction in market context
        ReplayWorker->>ReplayWorker: Calculate alternative outcomes
        
        ReplayWorker->>TransactionContext: Store replay results
        TransactionContext->>DB: Update replay_execution record
        DB-->>TransactionContext: Confirm update
        
        ReplayWorker->>AnalysisContext: Update performance metrics
        AnalysisContext->>DB: Update performance_summary
        DB-->>AnalysisContext: Confirm update
    end
    
    ReplayWorker->>ExecutionContext: Complete all replays
    ExecutionContext->>DB: Update backtest status to "completed"
    
    ExecutionContext->>WebUI: Notify completion (via PubSub)
    WebUI-->>Trader: Update UI with replay results
    
    Trader->>WebUI: View replay comparison
    WebUI->>AnalysisContext: Fetch comparative analysis
    AnalysisContext->>DB: Query replay results
    DB-->>AnalysisContext: Return data
    AnalysisContext-->>WebUI: Return formatted comparison
    WebUI-->>Trader: Display transaction comparison
```

## 4. Real-time Market Data Streaming Flow

This diagram illustrates how the system can stream real-time market data for live testing.

```mermaid
sequenceDiagram
    actor Trader
    participant WebUI as Phoenix LiveView UI
    participant WSChannel as WebSocket Channel
    participant StreamService as Stream Service
    participant BinanceStream as Binance Stream GenServer
    participant BinanceWS as Binance WebSocket API
    participant MarketDataContext as Market Data Context
    participant DB as PostgreSQL/TimescaleDB
    
    Trader->>WebUI: Select market(s) to monitor
    WebUI->>WSChannel: Subscribe to market updates
    WSChannel->>StreamService: Register client interest
    
    alt Stream already active
        StreamService->>WSChannel: Acknowledge subscription
    else New stream needed
        StreamService->>BinanceStream: Start stream for symbol
        BinanceStream->>BinanceStream: Initialize connection
        BinanceStream->>BinanceWS: Connect and subscribe to symbol stream
        BinanceWS-->>BinanceStream: Confirm subscription
        BinanceStream-->>StreamService: Stream started
        StreamService-->>WSChannel: Acknowledge subscription
    end
    
    WSChannel-->>WebUI: Channel joined
    WebUI-->>Trader: Display live connection status
    
    loop While connection active
        BinanceWS->>BinanceStream: Send price update
        BinanceStream->>BinanceStream: Process update
        
        par Broadcast to clients
            BinanceStream->>StreamService: Broadcast update
            StreamService->>WSChannel: Push update to channels
            WSChannel->>WebUI: Update UI
            WebUI-->>Trader: Display real-time price change
        and Store update
            BinanceStream->>MarketDataContext: Store latest data point
            MarketDataContext->>DB: Insert into market_data
        end
        
        BinanceStream->>BinanceStream: Check connection health (heartbeat)
    end
    
    alt Connection lost
        BinanceStream->>BinanceStream: Detect connection failure
        BinanceStream->>BinanceStream: Attempt reconnection with backoff
        BinanceStream->>BinanceWS: Reconnect
    end
    
    Trader->>WebUI: Unsubscribe from market
    WebUI->>WSChannel: Leave channel
    WSChannel->>StreamService: Unregister client
    
    alt No more clients for symbol
        StreamService->>BinanceStream: Stop stream
        BinanceStream->>BinanceWS: Unsubscribe
        BinanceStream->>BinanceStream: Terminate GenServer
    end
```

## 5. Chart and Trade Visualization Flow

This diagram shows how the system visualizes backtested trades on interactive charts.

```mermaid
sequenceDiagram
    actor Trader
    participant WebUI as Phoenix LiveView UI
    participant ChartComponent as Chart Component
    participant ChartHook as TradingView Chart Hook (JS)
    participant ExecutionContext as Execution Context
    participant MarketDataContext as Market Data Context
    participant DB as PostgreSQL/TimescaleDB
    
    Trader->>WebUI: View backtest results
    WebUI->>ChartComponent: Initialize chart for backtest
    
    ChartComponent->>ExecutionContext: Fetch backtest details
    ExecutionContext->>DB: Query backtest record
    DB-->>ExecutionContext: Return backtest data
    ExecutionContext-->>ChartComponent: Return symbol/timeframe/range
    
    ChartComponent->>MarketDataContext: Request market data
    MarketDataContext->>DB: Query market_data for range
    DB-->>MarketDataContext: Return OHLCV data
    MarketDataContext-->>ChartComponent: Return market data
    
    ChartComponent->>ExecutionContext: Fetch trades
    ExecutionContext->>DB: Query trades for backtest
    DB-->>ExecutionContext: Return trade details
    ExecutionContext-->>ChartComponent: Return trades
    
    ChartComponent->>ChartHook: Initialize chart (JS)
    ChartHook->>ChartHook: Create TradingView chart instance
    
    ChartComponent->>ChartHook: Load market data series
    ChartHook->>ChartHook: Create and populate price series
    
    ChartComponent->>ChartHook: Load indicator data
    ChartHook->>ChartHook: Add indicator series
    
    ChartComponent->>ChartHook: Add trade markers
    ChartHook->>ChartHook: Plot entry/exit points
    
    ChartHook-->>ChartComponent: Chart ready
    ChartComponent-->>WebUI: Render complete
    WebUI-->>Trader: Display interactive chart
    
    Trader->>WebUI: Interact with chart (zoom, pan)
    WebUI->>ChartHook: Handle user interaction
    ChartHook->>ChartHook: Update viewport
    
    alt Zoom requires more data
        ChartHook->>ChartComponent: Request additional data
        ChartComponent->>MarketDataContext: Fetch extended range
        MarketDataContext->>DB: Query additional market_data
        DB-->>MarketDataContext: Return extended data
        MarketDataContext-->>ChartComponent: Return additional data
        ChartComponent->>ChartHook: Load extended data
    end
    
    ChartHook-->>WebUI: Update chart display
    WebUI-->>Trader: Show updated view
    
    Trader->>WebUI: Click on trade marker
    WebUI->>ChartHook: Handle marker click
    ChartHook->>ChartComponent: Trade selection event
    ChartComponent->>WebUI: Display trade details
    WebUI-->>Trader: Show trade information popup
```

These detailed sequence diagrams illustrate the key processes and interactions in the Backtest System, providing a comprehensive view of how the different components work together to deliver the system's functionality. 