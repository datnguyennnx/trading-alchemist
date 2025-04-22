# Backtest System - Folder Structure

Based on the current implementation, here is the actual folder structure of the Backtest System.

## Current Folder Structure

```
lib/central/backtest/
├── core/                               # Core domain logic
│   ├── backtest.ex                     # Main entry point and public API
│   ├── strategy.ex                     # Strategy definition and management
│   ├── market_data.ex                  # Market data management
│   └── analysis.ex                     # Analysis and reporting
│
├── contexts/                           # Business logic contexts
│   ├── strategy_context.ex             # Strategy management context
│   ├── market_data_context.ex          # Market data context
│   ├── backtest_context.ex             # Backtest execution context
│   ├── analysis_context.ex             # Results analysis context
│   ├── transaction_context.ex          # Transaction history context
│   └── trade_context.ex                # Trade management context
│
├── schemas/                            # Database schema definitions
│   ├── strategy.ex                     # Strategy schema
│   ├── backtest.ex                     # Backtest schema
│   ├── market_data.ex                  # Market data schema
│   ├── trade.ex                        # Trade schema
│   └── performance_summary.ex          # Performance metrics schema
│
├── services/                           # Service layer
│   ├── execution/                      # Execution services
│   │   ├── strategy_executor.ex        # Strategy execution service
│   │   ├── rule_evaluator.ex           # Trading rule evaluation
│   │   └── trade_manager.ex            # Trade generation and management
│   │
│   ├── market_data/                    # Market data services
│   │   ├── market_data_handler.ex      # Market data operations
│   │   ├── historical_data_fetcher.ex  # Historical data fetching
│   │   └── data_processor.ex           # Data normalization and processing
│   │
│   ├── analysis/                       # Analysis services
│   │   ├── performance_calculator.ex   # Performance metrics calculation
│   │   └── reporting_service.ex        # Report generation
│   │
│   ├── risk/                           # Risk management services
│   │   ├── risk_manager.ex             # Position sizing and risk calc
│   │   └── position_sizer.ex           # Position size calculation
│   │
│   └── exchange/                       # Exchange API integration
│       └── binance/                    # Binance specific implementation
│           ├── client.ex               # Binance API client
│           └── stream.ex               # Binance WebSocket stream
│
├── workers/                            # Background workers
│   ├── market_sync_worker.ex           # Market data sync worker
│   └── backtest_runner_worker.ex       # Backtest execution worker
│
├── indicators/                         # Technical indicators
│   ├── indicators.ex                   # Public facade for all indicators
│   ├── list_indicator.ex               # List-based indicator calculations
│   ├── indicator_utils.ex              # Common utility functions for indicators
│   │
│   ├── calculations/                   # Shared calculation modules
│   ├── trend/                          # Trend indicators
│   ├── momentum/                       # Momentum indicators
│   ├── volatility/                     # Volatility indicators
│   ├── volume/                         # Volume indicators
│   └── levels/                         # Support/Resistance levels
│
├── dynamic_form/                       # Dynamic form generation
│   ├── form_context.ex                 # Form context service
│   ├── form_generator.ex               # Form generator service
│   ├── form_processor.ex               # Form processor service
│   ├── form_transformer.ex             # Form transformer service
│   └── rule.ex                         # Rule definition
│
└── utils/                              # Utility functions
    ├── datetime_utils.ex               # Date/time utilities
    ├── decimal_utils.ex                # Decimal number utilities
    ├── backtest_utils.ex               # Backtest-specific utilities
    └── trade_adapter.ex                # Trade data adapter utilities

```

## Implementation Notes

### Exchange Integration

The system currently implements a direct approach for exchange integration:

- Exchange-specific implementations are contained within their own directory (e.g., `services/exchange/binance/`)
- Each exchange has its own client and stream modules
- When adding a new exchange, you would:
  1. Create a new directory under `services/exchange/` for the exchange (e.g., `services/exchange/kraken/`)
  2. Implement client.ex and stream.ex modules specific to that exchange
  3. Update any services that need to use the new exchange client directly

### Potential Future Improvements

1. **Abstraction Layer**: Consider implementing a behavior module to define a common interface for exchange clients.

2. **Dynamic Exchange Selection**: Implement a factory pattern or adapter to dynamically select the appropriate exchange implementation.

3. **Configuration-Based Exchange**: Allow configuration of the exchange at runtime through environment variables or database settings.

### Key Design Principles

The current structure follows several important design principles:

1. **Domain-Driven Organization**: Components are organized by their domain function.

2. **Separation of Concerns**: 
   - Core modules define the public API
   - Contexts implement business logic
   - Services implement specific operations
   - Workers handle background processing

3. **Clear Module Boundaries**: Each module has a specific purpose with well-defined responsibilities.

4. **Service-Oriented Architecture**: Services are isolated with focused functionality.

This structure provides a solid foundation for future development and extension of the backtest system.
