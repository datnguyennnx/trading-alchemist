# Trading Indicator Module Structure Proposal

This proposal outlines a comprehensive folder structure for organizing indicator calculation modules within the `lib/central/backtest/indicators/` directory. The architecture is designed to support scalability and maintainability as the number of implemented indicators grows.

## Directory Structure

```
lib/central/backtest/indicators/
├── indicators.ex           # Public Facade: Entry point for using all indicators
├── calculations/           # Expanded calculations modules
│   ├── math.ex             # Math utilities (square root, safe division, etc.)
│   ├── normalization.ex    # Normalization functions
│   └── list_operations.ex  # List processing utilities
├── trend/
│   ├── moving_average.ex   # Simple, Exponential, Weighted MA
│   ├── macd.ex             # Moving Average Convergence Divergence
│   ├── ichimoku.ex         # Ichimoku Cloud components
│   ├── adx.ex              # Average Directional Index
│   ├── parabolic_sar.ex    # Parabolic Stop and Reverse
│   ├── donchian.ex         # Donchian Channels
│   ├── gmma.ex             # Guppy Multiple Moving Averages
│   ├── trix.ex             # Triple Exponential Average
│   ├── linear_regression.ex # Linear Regression indicators
│   └── fractals.ex         # Fractal patterns
├── momentum/
│   ├── rsi.ex              # Relative Strength Index
│   ├── stochastic.ex       # Stochastic Oscillator
│   ├── cci.ex              # Commodity Channel Index
│   ├── williams_r.ex       # Williams %R
│   ├── ultimate.ex         # Ultimate Oscillator
│   ├── roc.ex              # Rate of Change
│   ├── momentum.ex         # Simple momentum
│   ├── elder_ray.ex        # Elder-Ray Index
│   ├── tsi.ex              # True Strength Index
│   └── klinger.ex          # Klinger Oscillator
├── volatility/
│   ├── bollinger_bands.ex  # Bollinger Bands
│   ├── atr.ex              # Average True Range
│   ├── keltner.ex          # Keltner Channels
│   ├── std_dev.ex          # Standard Deviation
│   ├── chaikin.ex          # Chaikin Volatility
│   ├── projection_bands.ex # Projection Bands
│   └── volatility_ratio.ex # Volatility Ratio
├── volume/
│   ├── volume.ex           # Basic volume indicators
│   ├── obv.ex              # On-Balance Volume
│   ├── ad_line.ex          # Accumulation/Distribution Line
│   ├── cmf.ex              # Chaikin Money Flow
│   ├── mfi.ex              # Money Flow Index
│   ├── vpt.ex              # Volume Price Trend
│   ├── nvi_pvi.ex          # Negative/Positive Volume Index
│   ├── eom.ex              # Ease of Movement
│   └── force_index.ex      # Force Index
└── levels/
    ├── pivot_points.ex     # Various pivot point methods
    ├── fibonacci.ex        # Fibonacci retracements/extensions
    ├── psych_levels.ex     # Psychological levels
    └── channels.ex         # Various channel implementations
```

## Implementation Approach

### 1. Public Facade Pattern

The `indicators.ex` module serves as the unified public API for all indicators:

```elixir
defmodule Central.Backtest.Indicators do
  @moduledoc """
  Public facade for accessing all trading indicators.
  This module delegates to the appropriate specialized modules.
  """

  # Trend Indicators
  defdelegate sma(data, period), to: Central.Backtest.Indicators.Trend.MovingAverage
  defdelegate ema(data, period), to: Central.Backtest.Indicators.Trend.MovingAverage
  defdelegate macd(data, fast_period, slow_period, signal_period), to: Central.Backtest.Indicators.Trend.Macd
  
  # Momentum Indicators
  defdelegate rsi(data, period), to: Central.Backtest.Indicators.Momentum.Rsi
  defdelegate stochastic(data, k_period, d_period), to: Central.Backtest.Indicators.Momentum.Stochastic
  
  # Continue with other indicators...
end
```

### 2. Modular Implementation

Each indicator is implemented in its dedicated module with appropriate namespacing:

```elixir
defmodule Central.Backtest.Indicators.Trend.MovingAverage do
  @moduledoc """
  Implements various moving average calculations.
  """
  
  alias Central.Backtest.Indicators.Calculations.Math
  
  @doc """
  Calculates Simple Moving Average.
  
  ## Parameters
  
  - data: List of price values (typically closing prices)
  - period: Number of periods to include in the calculation
  
  ## Returns
  
  A list of SMA values corresponding to each input data point
  """
  def sma(data, period) when is_list(data) and is_integer(period) and period > 0 do
    # Implementation logic
  end
  
  @doc """
  Calculates Exponential Moving Average.
  """
  def ema(data, period) when is_list(data) and is_integer(period) and period > 0 do
    # Implementation logic
  end
  
  # Additional moving average types...
end
```

### 3. Shared Calculations

Common mathematical operations and utilities are centralized in the `calculations/` directory:

```elixir
defmodule Central.Backtest.Indicators.Calculations.Math do
  @moduledoc """
  Common mathematical functions used across various indicators.
  """
  
  @doc """
  Safe division that handles division by zero.
  Returns 0 when divisor is 0.
  """
  def safe_div(_numerator, 0), do: 0
  def safe_div(numerator, divisor), do: numerator / divisor
  
  # Other common math operations...
end
```

## Development Workflow

1. **Initial Development**: Start by implementing the most commonly used indicators in each category.
2. **Phased Growth**: Add more specialized indicators as needed, ensuring proper test coverage.
3. **Refactoring**: As the codebase grows, periodically review for opportunities to extract common patterns.
4. **Documentation**: Maintain comprehensive module and function documentation.

## Testing Strategy

- Unit tests for each indicator function
- Property-based tests for mathematical correctness
- Integration tests comparing results against known reference implementations
- Performance benchmarks for key indicators

## Future Considerations

- Support for custom/user-defined indicators
- Parallelization of indicator calculations when appropriate
- Optimization for memory usage and computation speed
- Streaming calculation for real-time indicator updates

This structure provides a balance between organization, flexibility, and future growth potential, while maintaining a clean and consistent public API through the facade pattern.