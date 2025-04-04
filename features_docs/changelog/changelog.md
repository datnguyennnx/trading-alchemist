# Changelog


## 2025-04-04: Core Infrastructure Implementation

### Database Schema Setup
- ✅ Set up PostgreSQL database with Docker and port configuration (5433)
- ✅ Enabled TimescaleDB extension in the database
- ✅ Created schema migrations with proper constraints and indices:
  - `market_data` table with TimescaleDB hypertable conversion
  - `users_auth_tables` via mix phx.gen.auth
  - `strategies` table with user reference
  - `backtests` table with strategy and user references
  - `trades` table with backtest reference
  - `performance_summaries` table with backtest reference
- ✅ Implemented composite primary key (id, timestamp) for the market_data hypertable
- ✅ Added proper indices for better query performance

### TradingView Chart Implementation
- ✅ Implemented real-time candlestick chart using lightweight-charts library
- ✅ Created Phoenix LiveView component with theme support (dark/light)
- ✅ Connected chart directly to TimescaleDB market data via Ecto queries
- ✅ Implemented symbol and timeframe selection (1m, 5m, 15m, 1h, 4h, 1d)
- ✅ Added realtime PubSub updates to chart when new data is available
- ✅ Optimized chart rendering with `phx-update="ignore"` for stateful DOM
- ✅ Fixed data transmission between LiveView and JavaScript with direct event pushing
- ✅ Added debug tools and error handling for chart display issues
- ✅ Implemented responsive design with automatic resizing on window changes

### Authentication System
- ✅ Implemented user authentication using `mix phx.gen.auth`
- ✅ Created LiveView-based authentication screens
- ✅ Set up user registration, login, password reset, and email confirmation
- ✅ Connected strategies and backtests to user accounts

### Market Data Synchronization
- ✅ Implemented TimescaleDB for high-performance time-series data storage
- ✅ Created GenServer-based market data sync worker for background processing
- ✅ Implemented incremental data synchronization with Binance API
- ✅ Added automatic retry and error handling for failed sync attempts
- ✅ Developed caching layer using ETS tables for high-frequency data access

### DevBox Integration
- ✅ Created Makefile with helpful development commands
- ✅ Updated devbox.json with Docker and database configurations
- ✅ Added scripts for database setup, migration, and Docker management
- ✅ Set environment variables for database connection

### Docker Configuration
- ✅ Implemented docker-compose.yml with PostgreSQL and TimescaleDB
- ✅ Configured Docker volumes for data persistence
- ✅ Set up port mapping to avoid conflicts (5433 instead of 5432)
- ✅ Added healthchecks for database container

### Schema Tests
- ✅ Created comprehensive test fixtures for all backtest entities:
  - `BacktestFixtures` module with fixtures for all schemas
- ✅ Implemented schema validation tests:
  - `MarketDataTest` - tests for market data schema validation and constraints
  - `StrategyTest` - tests for strategy schema validation and relationships
  - `BacktestTest` - tests for backtest schema validation and relationships
  - `TradeTest` - tests for trade schema validation and relationships
  - `PerformanceSummaryTest` - tests for performance metrics validation
- ✅ Added tests for:
  - Field validations and constraints
  - Foreign key relationships
  - Default values and required fields
  - Custom validations (e.g., timeframe format, date validations)
  - Unique constraints

### Context API Tests
- ✅ Implemented context API tests for business logic:
  - `MarketDataContextTest` - tests for market data querying and caching
- ✅ Covered key functionalities:
  - Data retrieval with date range filtering
  - Cache behavior for frequently accessed data
  - Query optimizations for time-series data
  - Edge cases and error handling

### Next Steps
- Enhance chart display with technical indicators (RSI, MACD, Moving Averages)
- Add drawing tools and annotations to the chart
- Implement the backtest engine
- Create strategy configuration UI
- Develop performance analytics tools

### Test Commands
- ✅ Run all tests: `MIX_ENV=test mix test`
- ✅ Run specific test file: `MIX_ENV=test mix test test/path/to/test_file.exs`
- ✅ Run schema tests:
  - `MIX_ENV=test mix test test/central/backtest/schemas/backtest_test.exs`
  - `MIX_ENV=test mix test test/central/backtest/schemas/strategy_test.exs`
  - `MIX_ENV=test mix test test/central/backtest/schemas/trade_test.exs`
  - `MIX_ENV=test mix test test/central/backtest/schemas/performance_summary_test.exs`
  - `MIX_ENV=test mix test test/central/backtest/schemas/market_data_test.exs`
- ✅ Run context tests: `MIX_ENV=test mix test test/central/backtest/contexts`
- ✅ Run web tests: `MIX_ENV=test mix test test/central_web`
- ✅ Run tests with coverage: `MIX_ENV=test mix test --cover`
- ✅ Run tests with detailed output: `MIX_ENV=test mix test --trace`
- ✅ Run tests matching specific module: `MIX_ENV=test mix test --only module:ModuleName`
- ✅ Run tests excluding specific tags: `MIX_ENV=test mix test --exclude slow`

### Configuration Modules
- ✅ Created `Central.Config.DateTime` module for consistent DateTime handling
  - Standardized DateTime truncation, formatting and timezone management
  - Added helper functions for date manipulation and parsing
  - Implemented timezone-aware formatting with configurable display options
- ✅ Created `Central.Config.HTTP` module for consistent HTTP status handling
  - Defined standard status code ranges (success, client error, server error)
  - Added error message extraction and formatting utilities
  - Implemented consistent error response structure

### Logging Enhancements
- ✅ Improved logger configuration with proper timestamp formatting
- ✅ Added date/time display in dd/mm/yyyy HH:MM:SS format for all logs
- ✅ Enhanced error logging with better readability and structure
- ✅ Enabled colored output for improved visual distinction of log levels

### Background Job Improvements
- ✅ Fixed issue in Market Sync Worker to properly handle state
- ✅ Enhanced error handling in HTTP client with proper error message extraction
- ✅ Improved response handling with standardized error format
