# Backtest System Coding Agent Instructions

## 1. Project Goal

To build a comprehensive backtesting system using Elixir and Phoenix. The system allows users to test trading strategies against historical market data (primarily from Binance), visualize results, analyze performance metrics, and replay historical transactions for consistent analysis.

## 2. Core Technologies

*   **Backend:** Elixir `~> 1.17`, Phoenix `~> 1.7`, Phoenix LiveView `~> 1.0`
*   **Database:** PostgreSQL, Ecto `~> 3.10`, TimescaleDB (for `market_data`)
*   **Frontend:** 
    - SaladUI (Component Library)
    - Tailwind CSS `~> 0.2`
    - Esbuild `~> 0.8`
    - TradingView Lightweight Charts (via hooks)
    - Lucide Icons
*   **APIs/Libs:** Tesla (HTTP), Finch (HTTP Client), Jason (JSON), Guardian (Auth, example), Vault concept (Encryption)
*   **Deployment:** Docker, Kubernetes (optional)

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
*   A standard Phoenix application interacts with PostgreSQL (enhanced with TimescaleDB).
*   Background workers handle data fetching and backtest execution.
*   Redis provides optional distributed caching.
*   External interaction primarily with the Binance API.

## 4. Key Features Overview

*   **Strategy Definition:** Users can define trading strategies with entry/exit rules and configurations via a UI.
*   **Backtesting Engine:** Executes strategies against historical `market_data` (OHLCV).
*   **Data Management:** Fetches and stores historical market data from Binance, handles normalization. TimescaleDB for time-series data.
*   **Performance Analysis:** Calculates various metrics (Win Rate, PnL, Drawdown, Sharpe Ratio, etc.).
*   **Visualization:** Interactive charts (TradingView) displaying price data, indicators, and trade executions. Results dashboards.
*   **Transaction Replay:** Imports user's historical transactions and replays them against potentially different market data for analysis.
*   **API Integration:** Core interaction with Binance REST and WebSocket APIs.
*   **Job Queuing & Parallelism:** Handles potentially long-running backtests concurrently.
*   **Security:** User authentication/authorization, secure API key storage, audit logging.

## 5. Database Schema Summary

*   `strategies`: Stores user-defined strategy configurations, rules.
*   `backtests`: Records details of each backtest run (symbol, timeframe, status, etc.).
*   `trades`: Stores simulated trades generated during a backtest.
*   `market_data`: Stores historical OHLCV price data (TimescaleDB Hypertable).
*   `performance_summaries`: Stores calculated performance metrics for a completed backtest.
*   `transaction_histories`: Stores imported user transaction records for replay.
*   `replay_executions`: Records the execution status and results of a transaction replay.
*   `(users)`: Standard user schema (from `Central.Accounts`, assumed pre-existing or standard Phoenix Auth).

## 6. Core Module Breakdown (`lib/central/backtest/`)

*   `contexts/`: Encapsulates business logic related to strategies, execution, analysis.
*   `schemas/`: Defines Ecto schemas mapping to database tables.
*   `services/`: Handles external API interactions (e.g., Binance), complex calculations (performance), or cross-cutting concerns (caching, API key management).
*   `workers/`: Contains GenServers/processes for background tasks (market data sync, backtest execution, transaction replay).
*   `validators/`: Modules for validating strategy rules or configurations.
*   `indicators/`: Modules for calculating technical indicators.
*   `risk_management/`: Modules related to position sizing and risk calculation.
*   `reporting/`: Modules for generating detailed reports.
*   `live/` (`lib/central_web/live/backtest/`): Phoenix LiveView modules and components for the UI.

## 7. Implementation Stages Summary

*   **Stage 1: Core Infrastructure**
    *   **Focus:** Establish database foundation, basic data fetching, and essential contexts.
    *   **Deliverables:** DB schemas (`Strategy`, `Backtest`, `Trade`, `MarketData`), TimescaleDB setup (`market_data` hypertable), Binance REST/WebSocket client basics, Market Sync Worker, `MarketData` context.
*   **Stage 2: Backtest Engine**
    *   **Focus:** Build the core strategy execution logic and performance calculation.
    *   **Deliverables:** `StrategyExecutor` service, Indicator calculation logic, `Performance` service, `PerformanceSummary` schema/generation, basic chart components, initial `ExecutionLive` view.
*   **Stage 3: User Interface**
    *   **Focus:** Develop the user-facing interfaces for strategy configuration and results analysis.
    *   **Deliverables:** `StrategyLive` view with form/rule builder components, enhanced interactive `ChartComponent`, `ResultsLive` dashboard with filtering/sorting, report export functionality, UI navigation/notifications.
*   **Stage 4: Optimization and Scalability**
    *   **Focus:** Improve performance and handling of larger workloads.
    *   **Deliverables:** Database query optimization (indexing), advanced caching (ETS/Redis), parallel backtest execution (Job Queue/Workers), performance monitoring tools.
*   **Stage 5: Transaction Replay, Security, and Production**
    *   **Focus:** Add transaction replay feature, harden security, and prepare for deployment.
    *   **Deliverables:** `TransactionHistory` / `ReplayExecution` schemas, transaction import service, replay execution service, secure API key management, RBAC/Audit logging implementation, Docker/K8s config, CI/CD pipeline setup, system health checks, final documentation.

## 8. Important Considerations

*   **Performance:** Leverage TimescaleDB for time-series queries. Implement caching (ETS, Redis). Optimize Ecto queries. Use background jobs for long tasks. (See Design Doc Sec 9).
*   **Security:** Use secure authentication. Encrypt sensitive data (API keys). Implement authorization (RBAC). Prevent common web vulnerabilities. Log audit trails. (See Design Doc Sec 11).
*   **Testing:** Comprehensive testing strategy including unit, integration, property-based, and end-to-end tests is crucial. (See Design Doc Sec 13).
*   **Infrastructure:** Plan for containerization (Docker) and potentially orchestration (Kubernetes). Implement robust monitoring and alerting. (See Design Doc Sec 12).

## 9. Source Document References

For detailed information, refer to:

*   `features_docs/backtest-docs-2025-Apr-2.md` (Main Design Document)
*   `features_docs/backtest_stage_1_implement.md`
*   `features_docs/backtest_stage_2_implement.md`
*   `features_docs/backtest_stage_3_implement.md`
*   `features_docs/backtest_stage_4_implement.md`
*   `features_docs/backtest_stage_5_implement.md`

## UI Components & Structure

The application uses SaladUI components for consistent UI patterns:

*   **Layout Components:**
    - `AppSidebar`: Main navigation with collapsible sections
    - `SettingsDialog`: Configurable settings modal
    - Reusable dialog/modal system

*   **Core UI Components:**
    - Sidebar (`CentralWeb.Components.UI.Sidebar`)
    - Collapsible sections (`CentralWeb.Components.UI.Collapsible`) 
    - Buttons (`CentralWeb.Components.UI.Button`)
    - Dropdowns (`CentralWeb.Components.UI.DropdownMenu`)
    - Menus (`CentralWeb.Components.UI.Menu`)
    - Icons (`CentralWeb.Components.UI.Icon`, using Lucide icons)

*   **LiveView Integration:**
    - Components use Phoenix.Component
    - LiveView JS commands for interactivity
    - Theme switching via LiveView hooks
    - Real-time updates via PubSub

*   **Custom Components:**
    - TradingView chart integration
    - Strategy builder interface
    - Performance metrics dashboard
    - Trade execution visualization 