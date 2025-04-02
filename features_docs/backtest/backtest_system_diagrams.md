# Backtest System Diagrams

This document presents visual representations of the backtest system architecture and implementation stages using mermaid diagrams.

## 1. High-Level System Architecture

This diagram shows the overall system architecture with its main layers.

```mermaid
graph TB
    subgraph Frontend
        UI[UI Layer - LiveView/SaladUI]
        Charts[TradingView Charts]
    end
    
    subgraph Application
        BC[Backtest Context]
        SC[Strategy Context]
        AC[Analysis Context]
        Workers[Background Workers]
    end
    
    subgraph "PostgreSQL Database"
        PG[Regular Tables]
        subgraph "TimescaleDB Extension" 
            TS[Market Data Hypertables]
        end
        PG --- TS
    end
    
    subgraph Cache
        RC[(Redis Cache)]
        ETS[ETS Tables]
    end
    
    subgraph External
        BA[Binance API]
    end
    
    UI --> BC
    UI --> SC
    UI --> AC
    Charts --> UI
    
    BC --> Workers
    SC --> Workers
    AC --> Workers
    
    Workers --> PG
    Workers --> TS
    Workers --> RC
    Workers --> ETS
    
    Workers --> BA
```

## 2. Database Schema Relationships

This diagram shows the relationships between the primary database schemas in the system.

```mermaid
erDiagram
    User ||--o{ Strategy : creates
    Strategy ||--o{ Backtest : executes
    Backtest ||--o{ Trade : generates
    Backtest ||--|| PerformanceSummary : has
    User ||--o{ TransactionHistory : imports
    TransactionHistory ||--o{ ReplayExecution : replays
    Backtest ||--o{ ReplayExecution : contains
    
    Strategy {
        string name
        text description
        map config
        map entry_rules
        map exit_rules
        boolean is_active
        boolean is_public
    }
    
    Backtest {
        datetime start_time
        datetime end_time
        string symbol
        string timeframe
        decimal initial_balance
        decimal final_balance
        enum status
        map metadata
    }
    
    Trade {
        datetime entry_time
        decimal entry_price
        datetime exit_time
        decimal exit_price
        decimal quantity
        enum side
        decimal pnl
        decimal fees
        array tags
        string entry_reason
        string exit_reason
    }
    
    MarketData {
        string symbol
        string timeframe
        datetime timestamp
        decimal open
        decimal high
        decimal low
        decimal close
        decimal volume
        string source
    }
    
    TransactionHistory {
        datetime transaction_time
        string symbol
        decimal price
        decimal quantity
        enum side
        enum transaction_type
        string transaction_id
        string exchange
        map metadata
        boolean is_replayed
    }
    
    ReplayExecution {
        datetime executed_at
        enum status
        map result
        map metadata
    }
    
    PerformanceSummary {
        integer total_trades
        integer winning_trades
        integer losing_trades
        decimal win_rate
        decimal profit_factor
        decimal max_drawdown
        decimal sharpe_ratio
        decimal total_pnl
        map metrics
    }
```

## 3. Folder Structure

This diagram represents the core folder structure of the backtest system.

```mermaid
graph TD
    root[lib/]
    central[central/]
    central_web[central_web/]
    backtest[backtest/]
    market_data[market_data/]
    contexts[contexts/]
    schemas[schemas/]
    services[services/]
    validators[validators/]
    indicators[indicators/]
    risk_management[risk_management/]
    reporting[reporting/]
    workers[workers/]
    binance[binance/]
    live[live/]
    components[components/]
    
    root --> central
    root --> central_web
    
    central --> backtest
    central --> market_data
    
    backtest --> contexts
    backtest --> schemas
    backtest --> services
    backtest --> validators
    backtest --> indicators
    backtest --> risk_management
    backtest --> reporting
    backtest --> workers
    
    services --> binance
    
    central_web --> live
    live --> components
    
    contexts --- ctx1[strategy.ex]
    contexts --- ctx2[execution.ex]
    contexts --- ctx3[analysis.ex]
    
    schemas --- sch1[strategy.ex]
    schemas --- sch2[backtest.ex]
    schemas --- sch3[trade.ex]
    schemas --- sch4[market_data.ex]
    schemas --- sch5[performance_summary.ex]
    schemas --- sch6[transaction_history.ex]
    schemas --- sch7[replay_execution.ex]
    
    binance --- bin1[client.ex]
    binance --- bin2[stream.ex]
    binance --- bin3[historical.ex]
    
    workers --- wrk1[market_sync.ex]
    workers --- wrk2[backtest_runner.ex]
    
    live --- lv1[strategy_live.ex]
    live --- lv2[execution_live.ex]
    live --- lv3[results_live.ex]
    
    components --- cmp1[strategy_form_component.ex]
    components --- cmp2[trade_table_component.ex]
    components --- cmp3[chart_component.ex]
    components --- cmp4[performance_metrics_component.ex]
```

## 4. Implementation Stages

### 4.1 Stage 1: Core Infrastructure

```mermaid
graph TB
    subgraph Stage1[Stage 1 - Core Infrastructure]
        DB[Database Schema Setup]
        MC[Market Data Context]
        BI[Binance Integration]
        MSW[Market Sync Worker]
    end
    
    subgraph "PostgreSQL with TimescaleDB"
        TSE[TimescaleDB Extension]
        MH[Market Data Hypertable]
        RT[Regular Tables]
        TSE --> |Convert| MH
    end
    
    DB --> |Create| RT
    DB --> |Enable| TSE
    DB --> |Create| S1[Strategy Schema]
    DB --> |Create| S2[Backtest Schema]
    DB --> |Create| S3[Trade Schema]
    DB --> |Create| S4[MarketData Schema]
    S4 --> |Convert to| MH
    
    BI --> C1[REST Client]
    BI --> C2[WebSocket Client]
    
    MC --> MD[Market Data Management]
    MC --> MDC[Market Data Caching]
    
    MSW --> MF[Market Data Fetcher]
    MSW --> MS[Market Data Storage]
    
    BI --> MSW
    MSW --> MC
    MC --> DB
```

### 4.2 Stage 2: Backtest Engine

```mermaid
graph TB
    subgraph Stage2[Stage 2 - Backtest Engine]
        SE[Strategy Executor]
        IC[Indicator Calculator]
        PC[Performance Calculator]
        PS[Performance Service]
        BC[Backtest Context]
    end
    
    IC --> I1[Moving Average]
    IC --> I2[RSI]
    IC --> I3[MACD]
    
    SE --> R1[Rule Evaluation]
    SE --> R2[Position Management]
    SE --> R3[Trade Generation]
    
    PC --> M1[Metrics Calculation]
    PC --> M2[Summary Generation]
    
    PS --> P1[PerformanceSummary Schema]
    PS --> P2[Metrics Storage]
    
    BC --> B1[Backtest Management]
    BC --> B2[Execution Flow]
    
    IC --> SE
    SE --> PC
    PC --> PS
    PS --> BC
```

### 4.3 Stage 3: User Interface

```mermaid
graph LR
    subgraph Stage3[Stage 3 - User Interface]
        SL[Strategy LiveView]
        EL[Execution LiveView]
        RL[Results LiveView]
        CO[Chart Components]
    end
    
    SL --> SF[Strategy Form]
    SL --> RB[Rule Builder]
    
    EL --> EC[Execution Controls]
    EL --> EP[Execution Progress]
    
    RL --> PD[Performance Dashboard]
    RL --> TT[Trade Table]
    RL --> EF[Export Functionality]
    
    CO --> TV[TradingView Integration]
    CO --> TS[Trade Signals Display]
    CO --> ZC[Zoom Controls]
    
    SL --> EL
    EL --> RL
    CO --> EL
    CO --> RL
```

### 4.4 Stage 4: Optimization and Scalability

```mermaid
graph TB
    subgraph Stage4[Stage 4 - Optimization]
        DBO[Database Optimization]
        PPE[Parallel Processing Engine]
        CL[Caching Layer]
        PM[Performance Monitoring]
    end
    
    subgraph "PostgreSQL + TimescaleDB Optimization"
        TSC[TimescaleDB Chunks]
        IDX[Database Indexes]
        QO[Query Optimization]
        CP[Connection Pool]
    end
    
    DBO --> IDX
    DBO --> TSC
    DBO --> QO
    DBO --> CP
    
    PPE --> P1[Worker Pool]
    PPE --> P2[Job Queue]
    PPE --> P3[Task Distribution]
    
    CL --> C1[ETS Tables]
    CL --> C2[Redis Implementation]
    CL --> C3[Cache Invalidation]
    
    PM --> M1[Telemetry Integration]
    PM --> M2[Metrics Dashboard]
    PM --> M3[Alerting System]
    
    DBO --> PPE
    PPE --> CL
    CL --> PM
```

### 4.5 Stage 5: Transaction Replay, Security, and Production

```mermaid
graph TB
    subgraph Stage5[Stage 5 - Production]
        TRS[Transaction Replay System]
        SEC[Security Implementation]
        DEP[Deployment Configuration]
        DOC[Documentation]
    end
    
    TRS --> T1[Transaction Import]
    TRS --> T2[Transaction Storage]
    TRS --> T3[Replay Execution Engine]
    
    SEC --> S1[API Key Management]
    SEC --> S2[RBAC Implementation]
    SEC --> S3[Audit Logging]
    
    DEP --> D1[Docker Configuration]
    DEP --> D2[CI/CD Pipeline]
    DEP --> D3[Health Checks]
    
    DOC --> DO1[API Documentation]
    DOC --> DO2[User Guide]
    DOC --> DO3[Developer Documentation]
    
    TRS --> SEC
    SEC --> DEP
    DEP --> DOC
```

## 5. Complete System Workflow

This diagram illustrates the end-to-end flow of the backtest system.

```mermaid
graph TB
    subgraph UserActions
        SB[Strategy Building]
        BE[Backtest Execution]
        RA[Results Analysis]
        TR[Transaction Replay]
    end
    
    subgraph CoreProcesses
        SD[Strategy Definition]
        ME[Market Execution]
        PC[Performance Calculation]
        TRE[Transaction Replay Engine]
    end
    
    subgraph DataFlow
        subgraph "PostgreSQL"
            RT[Regular Tables]
            subgraph "TimescaleDB"
                MD[Market Data]
            end
        end
        TD[Trade Data]
        PS[Performance Summary]
        TH[Transaction History]
    end
    
    SB --> |Configure| SD
    SD --> |Use| ME
    ME --> |Access| MD
    ME --> |Generate| TD
    TD --> |Calculate| PC
    PC --> |Store| PS
    PS --> |View| RA
    
    TR --> |Import| TH
    TH --> |Process| TRE
    TRE --> |Use| ME
    
    BE --> |Trigger| ME
    RA --> |Adjust| SB
```

## 6. Database Architecture

This diagram clarifies the relationship between PostgreSQL and TimescaleDB in the system.

```mermaid
graph TB
    subgraph "PostgreSQL Database Server"
        PG[PostgreSQL Engine]
        
        subgraph "Database Extensions"
            TS[TimescaleDB Extension]
        end
        
        PG --> TS
        
        subgraph "Regular PostgreSQL Tables"
            S[Strategies]
            B[Backtests]
            T[Trades]
            PS[Performance Summaries]
            TH[Transaction Histories]
            RE[Replay Executions]
        end
        
        subgraph "TimescaleDB Hypertables"
            MD[Market Data]
            style MD fill:#f9f,stroke:#333,stroke-width:2px
        end
        
        TS --> |Manages| MD
        PG --> |Manages| S
        PG --> |Manages| B
        PG --> |Manages| T
        PG --> |Manages| PS
        PG --> |Manages| TH
        PG --> |Manages| RE
    end
    
    subgraph "Application"
        EX[Elixir Application]
        EC[Ecto]
    end
    
    EX --> |Uses| EC
    EC --> |Connects to| PG
```

## 7. Component Interaction

This diagram shows how the Phoenix LiveView components interact with the backend contexts.

```mermaid
graph TB
    subgraph PhoenixComponents
        SLV[Strategy LiveView]
        ELV[Execution LiveView]
        RLV[Results LiveView]
    end
    
    subgraph UIComponents
        SF[Strategy Form]
        CC[Chart Component]
        TT[Trade Table]
        PM[Performance Metrics]
    end
    
    subgraph BackendContexts
        SC[Strategy Context]
        BC[Backtest Context]
        AC[Analysis Context]
    end
    
    subgraph BackgroundProcesses
        MSW[Market Sync Worker]
        BEW[Backtest Execution Worker]
        PW[Performance Worker]
    end
    
    SLV --> SF
    ELV --> CC
    RLV --> TT
    RLV --> PM
    
    SF --> SC
    CC --> BC
    TT --> BC
    PM --> AC
    
    SC --> BC
    BC --> AC
    
    BC --> BEW
    AC --> PW
    SC --> MSW
    
    BEW --> BC
    PW --> AC
    MSW --> SC
```

## 8. Security Architecture

```mermaid
graph TB
    subgraph AuthFlow
        AU[Authentication]
        AZ[Authorization]
        AL[Audit Logging]
    end
    
    subgraph DataProtection
        ES[Encryption at Storage]
        ET[Encryption in Transit]
        AK[API Key Management]
    end
    
    subgraph AccessControl
        RBAC[Role-Based Access]
        OA[Ownership Assessment]
        RC[Rate Control]
    end
    
    AU --> |Verify| AZ
    AZ --> |Record| AL
    
    AZ --> |Enforce| RBAC
    RBAC --> |Check| OA
    OA --> |Limit| RC
    
    AK --> |Secure with| ES
    AU --> |Use| ET
    AL --> |Store with| ES
```

## 9. Performance Optimization Flow

```mermaid
graph TB
    subgraph QueryOptimization
        subgraph "TimescaleDB Specific"
            TSC[TimescaleDB Chunks]
            HYP[Hypertable Optimization]
            TSQ[Time-Series Queries]
        end
        IDX[Database Indexing]
        QP[Query Planning]
    end
    
    subgraph CacheStrategy
        LRC[LRU Cache]
        ETS[ETS Tables]
        RC[Redis Cache]
    end
    
    subgraph ParallelExecution
        JQ[Job Queue]
        WP[Worker Pools]
        TS[Task Supervisors]
    end
    
    IDX --> |Speed up| QP
    TSC --> |Optimize| QP
    HYP --> |Enhances| TSQ
    TSQ --> |Improves| QP
    
    QP --> |Cache common| LRC
    LRC --> |Store in| ETS
    ETS --> |Distribute with| RC
    
    RC --> |Feed| JQ
    JQ --> |Process in| WP
    WP --> |Supervised by| TS
    
    TS --> |Update| RC
```

These diagrams represent the key components, workflows and architecture of the backtest system, based on the detailed analysis of the provided documentation. The relationship between PostgreSQL and TimescaleDB is now more clearly illustrated, showing that TimescaleDB is an extension within PostgreSQL rather than a separate database system. 