# Stage 2: Backtest Engine Implementation

## Overview
Building on the foundation established in Stage 1, we will now develop the core backtest engine. This includes implementing the strategy execution engine, performance analytics, and basic visualization components. This stage transforms our data foundation into a functional backtest system.

## Implementation Focus

### 1. Strategy Execution Engine (Week 1-2)
- Implement the strategy execution framework
- Create rule evaluators and position management
- Build indicator calculation system
- Develop transaction simulation logic

**Priority Tasks:**
1. Create the strategy execution framework
2. Implement rule evaluators for entry and exit conditions
3. Build position management with various order types
4. Develop indicator calculation system with common indicators

```elixir
# Sample strategy executor module
defmodule Central.Backtest.Services.StrategyExecutor do
  alias Central.Backtest.Contexts.MarketData
  alias Central.Backtest.Schema.{Strategy, Backtest, Trade}
  alias Central.Backtest.Services.Indicators
  alias Central.Repo
  
  def execute_backtest(backtest_id) do
    backtest = Repo.get!(Backtest, backtest_id) |> Repo.preload(:strategy)
    strategy = backtest.strategy
    
    # Get market data
    candles = MarketData.get_candles(
      backtest.symbol,
      backtest.timeframe,
      backtest.start_time,
      backtest.end_time
    )
    
    # Prepare initial state
    initial_state = %{
      balance: backtest.initial_balance,
      position: nil,
      trades: [],
      last_candle: nil,
      metrics: initialize_metrics()
    }
    
    # Execute strategy on each candle
    final_state = Enum.reduce(candles, initial_state, fn candle, state ->
      process_candle(candle, state, strategy)
    end)
    
    # Save results
    save_trades(final_state.trades, backtest_id)
    update_backtest_status(backtest_id, final_state)
    
    {:ok, final_state}
  end
  
  defp process_candle(candle, state, strategy) do
    # Calculate indicators
    indicators = calculate_indicators(candle, state.last_candle, strategy.config)
    
    # Evaluate entry if no position
    state = if is_nil(state.position) do
      case evaluate_entry_rules(strategy.entry_rules, candle, indicators) do
        true -> open_position(state, candle, strategy)
        false -> state
      end
    else
      # Evaluate exit if in position
      case evaluate_exit_rules(strategy.exit_rules, candle, indicators, state.position) do
        true -> close_position(state, candle)
        false -> state
      end
    end
    
    # Update state for next iteration
    %{state | last_candle: candle}
  end
  
  # Other helper functions for position management, rule evaluation, etc.
end
```

### 2. Performance Analytics (Week 3)
- Implement performance calculation algorithms
- Create risk analysis tools
- Build metrics computation system
- Develop performance reporting tools

**Priority Tasks:**
1. Implement key performance metrics (win rate, profit factor, etc.)
2. Create drawdown and risk analysis functions
3. Build trade analysis and categorization
4. Develop performance summary generator

```elixir
# Sample performance analytics module
defmodule Central.Backtest.Services.Performance do
  alias Central.Backtest.Schema.{Trade, Backtest, PerformanceSummary}
  alias Central.Repo
  import Ecto.Query
  
  def generate_performance_summary(backtest_id) do
    trades = 
      from(t in Trade, where: t.backtest_id == ^backtest_id)
      |> Repo.all()
    
    backtest = Repo.get!(Backtest, backtest_id)
    
    # Calculate basic metrics
    winning_trades = Enum.filter(trades, &(&1.pnl > 0))
    losing_trades = Enum.filter(trades, &(&1.pnl <= 0))
    
    win_rate = length(winning_trades) / max(length(trades), 1)
    
    total_profit = Enum.reduce(winning_trades, Decimal.new(0), &Decimal.add(&2, &1.pnl))
    total_loss = Enum.reduce(losing_trades, Decimal.new(0), &Decimal.add(&2, &1.pnl))
    
    profit_factor = if Decimal.compare(total_loss, Decimal.new(0)) == :gt do
      Decimal.div(total_profit, Decimal.abs(total_loss))
    else
      Decimal.new(999.99) # Avoid division by zero
    end
    
    # Additional metrics calculation...
    
    # Create and save performance summary
    %PerformanceSummary{}
    |> PerformanceSummary.changeset(%{
      backtest_id: backtest_id,
      total_trades: length(trades),
      winning_trades: length(winning_trades),
      losing_trades: length(losing_trades),
      win_rate: win_rate,
      profit_factor: profit_factor,
      # Add other calculated metrics...
    })
    |> Repo.insert!()
  end
  
  def calculate_drawdown(equity_curve) do
    # Implement drawdown calculation algorithm
  end
  
  def calculate_sharpe_ratio(returns, risk_free_rate \\ 0.0) do
    # Implement Sharpe ratio calculation
  end
  
  # Other performance metrics calculations
end
```

### 3. Basic Visualization Components (Week 4)
- Implement chart data formatting
- Create trade visualization on charts
- Build performance metrics display
- Develop equity curve visualization

**Priority Tasks:**
1. Create LiveView components for chart visualization
2. Implement trade markers on charts
3. Build performance metrics dashboard
4. Develop equity curve charting

```elixir
# Sample chart component
defmodule CentralWeb.ChartComponent do
  use Phoenix.LiveComponent
  alias Central.Backtest.Contexts.MarketData
  
  def render(assigns) do
    ~H"""
    <div id="chart-container" phx-hook="TradingViewChart" class="h-[500px] w-full" 
        data-candles={Jason.encode!(@candles)}
        data-trades={Jason.encode!(@trades)}
        data-theme={@theme}>
    </div>
    """
  end
  
  def update(%{symbol: symbol, timeframe: timeframe, start_time: start_time, end_time: end_time, trades: trades} = assigns, socket) do
    candles = MarketData.get_candles(symbol, timeframe, start_time, end_time)
    
    formatted_candles = format_candles_for_chart(candles)
    formatted_trades = format_trades_for_chart(trades)
    
    {:ok, 
      socket
      |> assign(assigns)
      |> assign(:candles, formatted_candles)
      |> assign(:trades, formatted_trades)
    }
  end
  
  defp format_candles_for_chart(candles) do
    Enum.map(candles, fn candle ->
      %{
        time: DateTime.to_unix(candle.timestamp),
        open: candle.open,
        high: candle.high,
        low: candle.low,
        close: candle.close,
        volume: candle.volume
      }
    end)
  end
  
  defp format_trades_for_chart(trades) do
    Enum.map(trades, fn trade ->
      %{
        time: DateTime.to_unix(trade.entry_time),
        price: trade.entry_price,
        type: if trade.side == :long, do: "buy", else: "sell",
        text: "Entry",
        color: if trade.side == :long, do: "#26a69a", else: "#ef5350",
        id: "entry-#{trade.id}"
      }
    end) ++
    Enum.map(trades, fn trade ->
      if trade.exit_time do
        %{
          time: DateTime.to_unix(trade.exit_time),
          price: trade.exit_price,
          type: if trade.side == :long, do: "sell", else: "buy",
          text: "Exit",
          color: if trade.pnl && Decimal.compare(trade.pnl, Decimal.new(0)) == :gt, do: "#26a69a", else: "#ef5350",
          id: "exit-#{trade.id}"
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
```

### 4. Initial Integration (Week 5)
- Connect all components in a functional system
- Set up LiveView coordinating system
- Implement initial UI flows
- Create user interaction logic

**Priority Tasks:**
1. Set up LiveView for backtest execution
2. Create basic UI for strategy configuration
3. Connect execution engine with visualization
4. Implement backtest results display

```elixir
# Sample LiveView module for backtest execution
defmodule CentralWeb.BacktestLive.Execution do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.{Strategy, Backtest}
  alias Central.Backtest.Workers.BacktestWorker
  
  def mount(%{"id" => strategy_id}, _session, socket) do
    strategy = Strategy.get_strategy!(strategy_id)
    
    {:ok, 
      socket
      |> assign(:strategy, strategy)
      |> assign(:form, to_form(%{"symbol" => "BTCUSDT", "timeframe" => "1h"}))
      |> assign(:status, :idle)
      |> assign(:backtest, nil)
    }
  end
  
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-2xl font-bold mb-4">Backtest: <%= @strategy.name %></h1>
      
      <.form for={@form} phx-submit="execute_backtest" class="mb-6">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <.input field={@form[:symbol]} label="Symbol" />
          </div>
          <div>
            <.input field={@form[:timeframe]} label="Timeframe" type="select" options={["1m", "5m", "15m", "1h", "4h", "1d"]} />
          </div>
          <div>
            <.input field={@form[:start_time]} label="Start Time" type="datetime-local" />
          </div>
          <div>
            <.input field={@form[:end_time]} label="End Time" type="datetime-local" />
          </div>
          <div>
            <.input field={@form[:initial_balance]} label="Initial Balance" type="number" step="0.01" />
          </div>
        </div>
        
        <.button type="submit" class="mt-4" phx-disable-with="Running...">Execute Backtest</.button>
      </.form>
      
      <%= if @status == :running do %>
        <div class="my-4 p-4 bg-blue-100 rounded">
          <p>Backtest is running...</p>
          <progress class="w-full" />
        </div>
      <% end %>
      
      <%= if @backtest && @backtest.status == :completed do %>
        <.live_component module={CentralWeb.ChartComponent}
          id="backtest-chart"
          symbol={@backtest.symbol}
          timeframe={@backtest.timeframe}
          start_time={@backtest.start_time}
          end_time={@backtest.end_time}
          trades={@backtest.trades}
          theme="dark"
        />
        
        <.live_component module={CentralWeb.PerformanceComponent}
          id="performance-metrics"
          backtest={@backtest}
        />
      <% end %>
    </div>
    """
  end
  
  def handle_event("execute_backtest", params, socket) do
    strategy_id = socket.assigns.strategy.id
    
    backtest_params = %{
      strategy_id: strategy_id,
      symbol: params["symbol"],
      timeframe: params["timeframe"],
      start_time: parse_datetime(params["start_time"]),
      end_time: parse_datetime(params["end_time"]),
      initial_balance: parse_decimal(params["initial_balance"]),
      status: :pending
    }
    
    case Backtest.create_backtest(backtest_params) do
      {:ok, backtest} ->
        # Start backtest in background worker
        BacktestWorker.perform_async(%{
          "backtest_id" => backtest.id
        })
        
        # Subscribe to backtest updates
        Phoenix.PubSub.subscribe(Central.PubSub, "backtest:#{backtest.id}")
        
        {:noreply, 
          socket
          |> assign(:status, :running)
          |> assign(:backtest, backtest)
        }
        
      {:error, changeset} ->
        {:noreply, 
          socket
          |> put_flash(:error, "Error creating backtest")
          |> assign(:form, to_form(changeset))
        }
    end
  end
  
  def handle_info({:backtest_update, backtest}, socket) do
    {:noreply, 
      socket
      |> assign(:status, :completed)
      |> assign(:backtest, backtest)
    }
  end
  
  # Helper functions for parsing form values
end
```

## Testing Strategy
- Implement detailed test suites for the strategy engine
- Create comprehensive tests for performance metrics calculations
- Test visualization components with browser tests
- Use property-based testing for edge cases

## Expected Deliverables
- Fully functional strategy execution engine
- Complete performance analytics suite
- Interactive chart visualization components
- Initial UI for backtest configuration and execution
- Comprehensive test coverage for all components

## Next Steps
After completing Stage 2, we will have a working backtest engine capable of executing strategies and visualizing results. The next stage will focus on enhancing the user interface, building the strategy configuration system, and creating a complete dashboard for analysis. 