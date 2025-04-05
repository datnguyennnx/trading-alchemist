<div align="center">
  <img src="./public/logo.png" width="300px" align="center" style="margin-bottom: -52px;" />
  <h1 style="border-bottom-width: 0px;" align="center">Trading Alchemist</h1>
  <blockquote> Trading Alchemist: Where market chaos confesses its secrets and your financial nightmares get a comedy reboot. The only tool that turns your "I should have bought Bitcoin in 2010" regrets into actionable intelligence without requiring a time machine.</blockquote>
</div>



## Overview

Trading Alchemist is a comprehensive trading analysis platform built with Elixir and Phoenix, leveraging TimescaleDB for efficient time-series data storage. The platform offers a robust backtesting system for cryptocurrency trading strategies with advanced analytics capabilities.

### Key Features

- **Strategy Builder**: Create, test, and refine trading strategies with flexible entry/exit rule configurations
- **Backtesting Engine**: Evaluate strategy performance against historical market data
- **Market Data Management**: Synchronization with Binance API for real-time and historical data
- **Performance Analytics**: Comprehensive metrics including win rate, profit factor, drawdown, Sharpe ratio
- **Transaction History**: Import and replay your actual trading history
- **Risk Management**: Configure position sizing, stop-loss, and take-profit settings

> For detailed feature documentation, explore the [features_docs](./features_docs) directory, especially the [backtest](./features_docs/backtest) section containing system diagrams, API designs, and implementation guidelines.

## System Architecture

Trading Alchemist is built with:

- **Phoenix Framework**: Web application and LiveView for real-time UI interactions
- **Elixir**: Core business logic with functional programming patterns
- **PostgreSQL with TimescaleDB**: Efficient storage for time-series market data
- **Redis and ETS**: Caching for performance optimization
- **Binance API Integration**: For market data retrieval

The system follows a modular architecture with contexts for:
- Strategy management
- Backtest execution
- Market data handling
- Performance analysis

### Prerequisites

- [DevBox](https://jetify.com/devbox) installed
- Docker and Docker Compose

### Quick Start

1. Clone the repository
2. Enter the DevBox shell:
   ```bash
   devbox shell
   ```
3. Start the development environment:
   ```bash
   devbox run dev
   ```

This will start the PostgreSQL container, migrate the database, and start the Phoenix server.

### Available Commands

All commands are available through DevBox:

```bash
# Show all available commands
devbox run help

# Start just the database in Docker
devbox run docker.up

# Stop all Docker containers
devbox run docker.down

# Setup the database (create and migrate)
devbox run db.setup

# Reset the database (drop, create, and migrate)
devbox run db.reset

# Run database migrations
devbox run db.migrate

# Seed the database
devbox run db.seed

# Start the Phoenix server
devbox run start

# Stop the Phoenix server
devbox run stop

# Clean compiled artifacts
devbox run clean

# Setup full development environment (db + server)
devbox run dev
```

### Manual Setup

If you prefer not to use DevBox, you can use the Makefile directly:

```bash
# Show all available commands
make help

# Start the PostgreSQL container
make docker.up

# Start the full development environment
make dev
```

### Environment Variables

The application is configured to use the following environment variables for database connection:

- `POSTGRES_HOST` (default: "localhost")
- `POSTGRES_USER` (default: "postgres")
- `POSTGRES_PASSWORD` (default: "postgres")
- `POSTGRES_DB` (default: "central_dev")
- `POSTGRES_PORT` (default: "5433")

These are automatically set when using DevBox.

## API Endpoints

The platform provides RESTful API endpoints for:
- Authentication and session management
- Strategy CRUD operations
- Backtest execution and analysis
- Market data retrieval

For detailed API documentation, refer to the API Design docs.

## TimescaleDB

This project uses TimescaleDB for efficient time-series data storage. The database is configured with hypertables for market data to optimize time-series queries.

## Learn more

* [Phoenix Framework](https://www.phoenixframework.org/)
* [Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)
* [Phoenix Documentation](https://hexdocs.pm/phoenix)
* [TimescaleDB Documentation](https://docs.timescale.com/)
* [Elixir Forum](https://elixirforum.com/)
