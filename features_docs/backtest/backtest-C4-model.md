# Backtest System C4 Model Architecture

This document presents a comprehensive C4 model for the Backtest System, visualizing its architecture across different levels of abstraction.

## 1. Level 1: System Context Diagram

The System Context diagram shows the Backtest System in relation to its users and external dependencies.

```mermaid
graph TB
    Trader[Trader]
    BacktestSystem[Backtest System]
    BinanceAPI[Binance API]
    
    Trader -->|Uses| BacktestSystem
    BacktestSystem -->|Fetches data from| BinanceAPI
```

## 2. Level 2: Container Diagram

The Container diagram shows the high-level technical building blocks that make up the Backtest System.

```mermaid
graph TB
    Trader[Trader]
    BinanceAPI[Binance API]

    subgraph BacktestSystem[Backtest System]
        WebApp[Phoenix Web Application]
        ElixirApp[Elixir Application]
        BgWorkers[Background Workers<br/><br/>Handles long-running tasks<br/>like data fetching and<br/>backtest execution]
        Database[(PostgreSQL Database<br/><br/>Stores strategies, backtests,<br/>trades, and market data<br/>with TimescaleDB extension)]
        CacheLayer[Cache Layer<br/><br/>Improves performance with<br/>ETS tables and Redis]
    end
    
    Trader -->|Interacts with| WebApp
    WebApp -->|Uses| ElixirApp
    ElixirApp -->|Uses| Database
    ElixirApp -->|Stores/retrieves data from| CacheLayer
    ElixirApp -->|Delegates long-running tasks to| BgWorkers
    BgWorkers -->|Updates| Database
    BgWorkers -->|Fetches data from| BinanceAPI
```

## 3. Level 3: Component Diagram

The Component diagram shows the key components inside the Elixir Application container.

```mermaid
graph TB
    WebApp[Phoenix Web Application]
    Database[(PostgreSQL Database)]
    BinanceAPI[Binance API]
    BgWorkers[Background Workers]

    subgraph ElixirApp[Elixir Application]
        StrategyCtx[Strategy Context<br/><br/>Manages strategy<br/>definitions and rules]
        BacktestCtx[Backtest Context<br/><br/>Executes backtests<br/>against historical data]
        MarketDataCtx[Market Data Context<br/><br/>Handles market data<br/>retrieval and storage]
        AnalysisCtx[Analysis Context<br/><br/>Analyzes backtest results<br/>and generates reports]
        
        IndicatorCalc[Indicators Module<br/><br/>Calculates technical indicators]
        BinanceService[Binance Service<br/><br/>Handles communication<br/>with Binance API]
        Validators[Validators<br/><br/>Validates strategy rules<br/>and configurations]
        Reports[Reporting Services<br/><br/>Generates performance<br/>reports and metrics]
        
        TransactionHistory[Transaction History<br/><br/>Manages imported user<br/>transactions]
        ReplayExec[Replay Execution<br/><br/>Replays historical<br/>transactions]
        RiskMgmt[Risk Management<br/><br/>Handles position sizing<br/>and risk calculations]
        PerfCalc[Performance Calculator<br/><br/>Computes performance<br/>metrics and statistics]
    end
    
    WebApp -->|Uses| StrategyCtx
    WebApp -->|Uses| BacktestCtx
    WebApp -->|Uses| AnalysisCtx
    
    StrategyCtx -->|Uses| Validators
    StrategyCtx -->|Stored in| Database
    
    BacktestCtx -->|Uses| MarketDataCtx
    BacktestCtx -->|Uses| IndicatorCalc
    BacktestCtx -->|Uses| RiskMgmt
    BacktestCtx -->|Executes via| BgWorkers
    BacktestCtx -->|Stored in| Database
    
    MarketDataCtx -->|Uses| BinanceService
    MarketDataCtx -->|Stored in| Database
    
    AnalysisCtx -->|Uses| PerfCalc
    AnalysisCtx -->|Uses| Reports
    AnalysisCtx -->|Stored in| Database
    
    BinanceService -->|Communicates with| BinanceAPI
    
    TransactionHistory -->|Uses| ReplayExec
    ReplayExec -->|Uses| BacktestCtx
```

## 4. Code Level Diagram: Database Schema Relationships

This diagram shows the key database schema relationships in the system.

```mermaid
erDiagram
    User ||--o{ Strategy : creates
    User ||--o{ Backtest : owns
    User ||--o{ TransactionHistory : imports
    
    Strategy ||--o{ Backtest : executes
    Backtest ||--o{ Trade : generates
    Backtest ||--|| PerformanceSummary : has
    
    TransactionHistory ||--o{ ReplayExecution : replays
    Backtest ||--o{ ReplayExecution : contains
    
    Strategy {
        id uuid PK
        name string
        description text
        config map
        entry_rules map
        exit_rules map
        is_active boolean
        is_public boolean
        user_id uuid FK
    }
    
    Backtest {
        id uuid PK
        start_time datetime
        end_time datetime
        symbol string
        timeframe string
        initial_balance decimal
        final_balance decimal
        status enum
        metadata map
        strategy_id uuid FK
        user_id uuid FK
    }
    
    Trade {
        id uuid PK
        entry_time datetime
        entry_price decimal
        exit_time datetime
        exit_price decimal
        quantity decimal
        side enum
        pnl decimal
        pnl_percentage decimal
        fees decimal
        tags array
        entry_reason string
        exit_reason string
        metadata map
        backtest_id uuid FK
    }
    
    MarketData {
        id uuid PK
        symbol string
        timeframe string
        timestamp datetime
        open decimal
        high decimal
        low decimal
        close decimal
        volume decimal
        source string
    }
    
    TransactionHistory {
        id uuid PK
        transaction_time datetime
        symbol string
        price decimal
        quantity decimal
        side enum
        transaction_type enum
        transaction_id string
        exchange string
        metadata map
        is_replayed boolean
        user_id uuid FK
    }
    
    ReplayExecution {
        id uuid PK
        executed_at datetime
        status enum
        result map
        metadata map
        transaction_history_id uuid FK
        backtest_id uuid FK
    }
    
    PerformanceSummary {
        id uuid PK
        total_trades integer
        winning_trades integer
        losing_trades integer
        win_rate decimal
        profit_factor decimal
        max_drawdown decimal
        max_drawdown_percentage decimal
        sharpe_ratio decimal
        sortino_ratio decimal
        total_pnl decimal
        total_pnl_percentage decimal
        average_win decimal
        average_loss decimal
        largest_win decimal
        largest_loss decimal
        metrics map
        backtest_id uuid FK
    }
```

## 5. Deployment Diagram

The Deployment diagram shows the runtime infrastructure for the Backtest System.

```mermaid
graph TB
    subgraph Cloud[Cloud Infrastructure]
        subgraph DockerCluster[Docker/Kubernetes Cluster]
            LoadBalancer[Load Balancer]
            
            subgraph PhoenixPods[Phoenix Application Pods]
                PhoenixNode1[Phoenix Node 1]
                PhoenixNode2[Phoenix Node 2]
                PhoenixNodeN[Phoenix Node N]
            end
            
            subgraph WorkerPods[Background Worker Pods]
                WorkerNode1[Worker Node 1]
                WorkerNode2[Worker Node 2]
                WorkerNodeN[Worker Node N]
            end
            
            Redis[(Redis Cache)]
        end
        
        subgraph DatabaseCluster[Database Cluster]
            PostgreSQL[(PostgreSQL with TimescaleDB)]
        end
    end
    
    BinanceAPI[Binance API]
    
    LoadBalancer -->|Routes traffic to| PhoenixPods
    PhoenixPods -->|Use| Redis
    PhoenixPods -->|Read/Write| PostgreSQL
    WorkerPods -->|Use| Redis
    WorkerPods -->|Read/Write| PostgreSQL
    WorkerPods -->|Fetch data from| BinanceAPI
```

## 6. Dynamic View: Backtest Execution Flow

This diagram shows the sequence of operations during a backtest execution.

```mermaid
sequenceDiagram
    actor Trader
    participant UI as Phoenix LiveView
    participant BacktestCtx as Backtest Context
    participant BgWorker as Background Worker
    participant MarketData as Market Data Context
    participant DB as PostgreSQL Database
    participant Cache as Cache Layer
    participant External as Binance API
    
    Trader->>UI: Configure and start backtest
    UI->>BacktestCtx: Create backtest record
    BacktestCtx->>DB: Store backtest configuration
    BacktestCtx->>BgWorker: Queue backtest execution
    UI->>Trader: Display pending status
    
    BgWorker->>MarketData: Request historical data
    MarketData->>Cache: Check cache for data
    
    alt Data in cache
        Cache->>MarketData: Return cached data
    else Data not in cache
        MarketData->>DB: Query database
        alt Data in database
            DB->>MarketData: Return market data
        else Data not in database
            MarketData->>External: Fetch from Binance API
            External->>MarketData: Return market data
            MarketData->>DB: Store market data
        end
        MarketData->>Cache: Cache market data
    end
    
    MarketData->>BgWorker: Return historical data
    BgWorker->>BgWorker: Execute backtest strategy
    BgWorker->>DB: Store trade results
    BgWorker->>BgWorker: Calculate performance metrics
    BgWorker->>DB: Store performance summary
    BgWorker->>BacktestCtx: Notify completion
    BacktestCtx->>UI: Update UI with results
    UI->>Trader: Display backtest results
```

## 7. Key Architectural Characteristics

```mermaid
graph TD
    Architecture[Backtest System Architecture]
    
    Architecture --> Modularity[Modularity<br/><br/>Contexts pattern for<br/>separation of concerns]
    Architecture --> Performance[Performance<br/><br/>TimescaleDB, caching and<br/>parallel processing]
    Architecture --> Scalability[Scalability<br/><br/>Horizontal scaling with<br/>containerization]
    Architecture --> Security[Security<br/><br/>Authentication, authorization,<br/>and encrypted API keys]
    Architecture --> Maintainability[Maintainability<br/><br/>Clear module boundaries<br/>and comprehensive testing]
    Architecture --> UserExperience[User Experience<br/><br/>Real-time UI with LiveView<br/>and TradingView charts]
```

## 8. Implementation Phases

This diagram shows the planned implementation stages for the Backtest System.

```mermaid
gantt
    title Backtest System Implementation Phases
    dateFormat  YYYY-MM-DD
    section Stage 1: Core Infrastructure
    Database Schema Setup       :a1, 2025-04-01, 5d
    Market Data Context         :a2, after a1, 7d
    Binance Integration         :a3, after a1, 8d
    Market Sync Worker          :a4, after a3, 5d
    
    section Stage 2: Backtest Engine
    Strategy Executor           :b1, after a4, 8d
    Indicator Calculation       :b2, after a4, 6d
    Performance Service         :b3, after b1, 7d
    Execution LiveView (Basic)  :b4, after b3, 5d
    
    section Stage 3: User Interface
    Strategy LiveView           :c1, after b4, 7d
    Chart Components            :c2, after b4, 8d
    Results LiveView            :c3, after c2, 6d
    UI Navigation/Notifications :c4, after c3, 4d
    
    section Stage 4: Optimization
    Database Optimization       :d1, after c4, 6d
    Caching Implementation      :d2, after c4, 7d
    Parallel Processing         :d3, after d2, 7d
    Performance Monitoring      :d4, after d3, 5d
    
    section Stage 5: Final Features
    Transaction Replay          :e1, after d4, 8d
    Security Implementation     :e2, after d4, 7d
    Deployment Configuration    :e3, after e2, 6d
    Documentation               :e4, after e3, 5d
```

## 9. Key Design Decisions

This diagram highlights the key design decisions that underpin the Backtest System.

```mermaid
mindmap
  root((Backtest System<br>Design Decisions))
    Database
      PostgreSQL as main database
      TimescaleDB for market data
      Partitioning by symbol and time
      Materialized views for aggregations
    Technology Stack
      Elixir/Phoenix framework
      Phoenix LiveView for UI
      TradingView Lightweight Charts
      SaladUI component library
    Architecture
      Context-based modular design
      Background workers for long tasks
      Caching strategy (ETS/Redis)
      Event-driven with PubSub
    Processing
      Parallel backtest execution
      Task-based concurrent processing
      Job queuing for long-running tasks
      Optimized time-series queries
    Security
      Secure API key storage
      Role-based access control
      Audit logging
      Authentication with Guardian
    Deployment
      Docker containerization
      Kubernetes orchestration
      CI/CD pipeline
      Health monitoring
```

## 10. Summary

The C4 model provides multiple perspectives on the Backtest System architecture, from high-level context through containers and components down to code-level relationships. This hierarchical approach helps stakeholders understand the system at the appropriate level of detail for their needs.

Key architectural features include:

1. **Modular Design**: Using Phoenix's context pattern for clean separation of concerns
2. **Time-Series Optimization**: Leveraging TimescaleDB for efficient market data storage and retrieval
3. **Real-Time UI**: Phoenix LiveView for a responsive, reactive user experience
4. **Parallel Processing**: Background workers for handling computation-intensive tasks
5. **Multi-Level Caching**: ETS tables and Redis for optimized performance
6. **Security Focus**: Proper authentication, authorization, and secure API key management
7. **Scalable Infrastructure**: Docker/Kubernetes configuration for horizontal scaling 