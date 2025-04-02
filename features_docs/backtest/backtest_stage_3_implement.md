# Stage 3: User Interface Implementation

## Overview
Building on the core backtest engine developed in Stage 2, this phase focuses on creating a complete and intuitive user interface. We'll implement a strategy configuration system, develop interactive charting capabilities, and build comprehensive dashboards for result analysis.

## Implementation Focus

### 1. Strategy Configuration Interface (Week 1-2)
- Build an intuitive strategy creation UI
- Implement visual rule builder for entry/exit conditions
- Create parameter configuration interface
- Develop strategy testing and validation tools

**Priority Tasks:**
1. Create strategy management LiveView
2. Implement visual rule builder component
3. Build parameter configuration form
4. Develop strategy validation functionality

```elixir
# Sample strategy form component
defmodule CentralWeb.StrategyLive.FormComponent do
  use CentralWeb, :live_component
  alias Central.Backtest.Contexts.Strategy
  
  def render(assigns) do
    ~H"""
    <div class="bg-white p-6 rounded-lg shadow">
      <h2 class="text-xl font-bold mb-4"><%= @title %></h2>
      
      <.form for={@form} phx-submit="save" phx-target={@myself} phx-change="validate">
        <div class="space-y-4">
          <div>
            <.input field={@form[:name]} label="Strategy Name" required />
          </div>
          
          <div>
            <.input field={@form[:description]} label="Description" type="textarea" />
          </div>
          
          <div class="border rounded-md p-4">
            <h3 class="text-lg font-semibold mb-2">Entry Rules</h3>
            <.live_component module={CentralWeb.RuleBuilderComponent}
              id="entry-rules"
              field={@form[:entry_rules]}
              available_indicators={@available_indicators}
              on_change={JS.push("update_entry_rules", target: @myself)}
            />
          </div>
          
          <div class="border rounded-md p-4">
            <h3 class="text-lg font-semibold mb-2">Exit Rules</h3>
            <.live_component module={CentralWeb.RuleBuilderComponent}
              id="exit-rules"
              field={@form[:exit_rules]}
              available_indicators={@available_indicators}
              on_change={JS.push("update_exit_rules", target: @myself)}
            />
          </div>
          
          <div class="border rounded-md p-4">
            <h3 class="text-lg font-semibold mb-2">Configuration</h3>
            <.live_component module={CentralWeb.StrategyConfigComponent}
              id="strategy-config"
              field={@form[:config]}
              on_change={JS.push("update_config", target: @myself)}
            />
          </div>
        </div>
        
        <div class="mt-6 flex justify-end space-x-2">
          <.button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="px-4 py-2 bg-gray-200 text-gray-800 rounded"
          >
            Cancel
          </.button>
          <.button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded">
            Save Strategy
          </.button>
        </div>
      </.form>
    </div>
    """
  end
  
  def update(%{strategy: strategy} = assigns, socket) do
    changeset = Strategy.change_strategy(strategy)
    
    {:ok,
      socket
      |> assign(assigns)
      |> assign_form(changeset)
      |> assign(:available_indicators, get_available_indicators())
    }
  end
  
  def handle_event("validate", %{"strategy" => strategy_params}, socket) do
    changeset =
      socket.assigns.strategy
      |> Strategy.change_strategy(strategy_params)
      |> Map.put(:action, :validate)
      
    {:noreply, assign_form(socket, changeset)}
  end
  
  def handle_event("save", %{"strategy" => strategy_params}, socket) do
    save_strategy(socket, socket.assigns.action, strategy_params)
  end
  
  def handle_event("update_entry_rules", %{"rules" => rules}, socket) do
    # Update entry rules in form
    {:noreply, update_form_field(socket, :entry_rules, rules)}
  end
  
  def handle_event("update_exit_rules", %{"rules" => rules}, socket) do
    # Update exit rules in form
    {:noreply, update_form_field(socket, :exit_rules, rules)}
  end
  
  def handle_event("update_config", %{"config" => config}, socket) do
    # Update config in form
    {:noreply, update_form_field(socket, :config, config)}
  end
  
  defp save_strategy(socket, :edit, strategy_params) do
    case Strategy.update_strategy(socket.assigns.strategy, strategy_params) do
      {:ok, strategy} ->
        {:noreply,
          socket
          |> put_flash(:info, "Strategy updated successfully")
          |> push_navigate(to: ~p"/strategies/#{strategy}")
        }
        
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end
  
  defp save_strategy(socket, :new, strategy_params) do
    # Add current user ID to params
    strategy_params = Map.put(strategy_params, "user_id", socket.assigns.current_user.id)
    
    case Strategy.create_strategy(strategy_params) do
      {:ok, strategy} ->
        {:noreply,
          socket
          |> put_flash(:info, "Strategy created successfully")
          |> push_navigate(to: ~p"/strategies/#{strategy}")
        }
        
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end
  
  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
  
  defp update_form_field(socket, field, value) do
    current_params = socket.assigns.form.params
    updated_params = Map.put(current_params, Atom.to_string(field), value)
    changeset = Strategy.change_strategy(socket.assigns.strategy, updated_params)
    assign_form(socket, changeset)
  end
  
  defp get_available_indicators do
    [
      %{id: "sma", name: "Simple Moving Average", params: ["period", "source"]},
      %{id: "ema", name: "Exponential Moving Average", params: ["period", "source"]},
      %{id: "rsi", name: "Relative Strength Index", params: ["period"]},
      %{id: "macd", name: "MACD", params: ["fast_period", "slow_period", "signal_period"]},
      %{id: "bbands", name: "Bollinger Bands", params: ["period", "deviation_up", "deviation_down"]}
    ]
  end
end
```

### 2. Interactive Charting (Week 3)
- Enhance chart components with interactivity
- Implement technical indicators on charts
- Add user customization options
- Build trade visualization enhancements

**Priority Tasks:**
1. Improve chart component with additional features
2. Add technical indicators display
3. Implement chart settings customization
4. Enhance trade visualization with details

```elixir
# Sample enhanced chart component
defmodule CentralWeb.EnhancedChartComponent do
  use Phoenix.LiveComponent
  alias Central.Backtest.Contexts.MarketData
  alias Central.Backtest.Services.Indicators
  
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h3 class="text-lg font-semibold"><%= @symbol %> - <%= @timeframe %></h3>
        
        <div class="flex space-x-2">
          <div class="dropdown">
            <.button id="indicator-dropdown" class="dropdown-toggle">
              Add Indicator
              <span class="ml-2">▼</span>
            </.button>
            <div class="dropdown-menu">
              <%= for indicator <- @available_indicators do %>
                <a href="#" phx-click="add_indicator" phx-value-indicator={indicator.id} phx-target={@myself}>
                  <%= indicator.name %>
                </a>
              <% end %>
            </div>
          </div>
          
          <.button phx-click="chart_settings" phx-target={@myself}>
            <i class="icon icon-settings"></i>
          </.button>
        </div>
      </div>
      
      <div id={"chart-container-#{@id}"} phx-hook="EnhancedTradingViewChart" class="h-[600px] w-full border rounded" 
          data-candles={Jason.encode!(@candles)}
          data-trades={Jason.encode!(@trades)}
          data-indicators={Jason.encode!(@active_indicators)}
          data-theme={@theme}>
      </div>
      
      <%= if @selected_trade do %>
        <.live_component module={CentralWeb.TradeDetailsComponent}
          id="trade-details"
          trade={@selected_trade}
        />
      <% end %>
    </div>
    """
  end
  
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_defaults()
      |> load_chart_data()
      
    {:ok, socket}
  end
  
  defp assign_defaults(socket) do
    if !Map.has_key?(socket.assigns, :active_indicators) do
      socket
      |> assign(:active_indicators, [])
      |> assign(:available_indicators, get_available_indicators())
      |> assign(:selected_trade, nil)
      |> assign(:theme, "dark")
    else
      socket
    end
  end
  
  defp load_chart_data(socket) do
    %{symbol: symbol, timeframe: timeframe, start_time: start_time, end_time: end_time, trades: trades} = socket.assigns
    
    candles = MarketData.get_candles(symbol, timeframe, start_time, end_time)
    
    # Calculate indicators
    indicator_data = calculate_indicators(candles, socket.assigns.active_indicators)
    
    formatted_candles = format_candles_for_chart(candles)
    formatted_trades = format_trades_for_chart(trades)
    
    socket
    |> assign(:candles, formatted_candles)
    |> assign(:trades, formatted_trades)
    |> assign(:indicator_data, indicator_data)
  end
  
  def handle_event("add_indicator", %{"indicator" => indicator_id}, socket) do
    # Add indicator to active list with default params
    indicator_config = find_indicator_by_id(indicator_id, socket.assigns.available_indicators)
    
    default_params = case indicator_id do
      "sma" -> %{"period" => 20, "source" => "close"}
      "ema" -> %{"period" => 14, "source" => "close"}
      "rsi" -> %{"period" => 14}
      "macd" -> %{"fast_period" => 12, "slow_period" => 26, "signal_period" => 9}
      "bbands" -> %{"period" => 20, "deviation_up" => 2, "deviation_down" => 2}
      _ -> %{}
    end
    
    new_indicator = %{
      id: "#{indicator_id}_#{:rand.uniform(1000)}",
      type: indicator_id,
      params: default_params
    }
    
    new_active_indicators = socket.assigns.active_indicators ++ [new_indicator]
    
    {:noreply,
      socket
      |> assign(:active_indicators, new_active_indicators)
      |> load_chart_data()
    }
  end
  
  def handle_event("remove_indicator", %{"indicator_id" => indicator_id}, socket) do
    new_active_indicators = Enum.reject(socket.assigns.active_indicators, &(&1.id == indicator_id))
    
    {:noreply,
      socket
      |> assign(:active_indicators, new_active_indicators)
      |> load_chart_data()
    }
  end
  
  def handle_event("select_trade", %{"trade_id" => trade_id}, socket) do
    selected_trade = Enum.find(socket.assigns.trades, &(&1.id == String.to_integer(trade_id)))
    
    {:noreply, assign(socket, :selected_trade, selected_trade)}
  end
  
  defp calculate_indicators(candles, active_indicators) do
    Enum.map(active_indicators, fn indicator ->
      case indicator.type do
        "sma" -> 
          values = Indicators.sma(candles, indicator.params["period"], indicator.params["source"])
          %{id: indicator.id, type: indicator.type, values: values}
        "ema" -> 
          values = Indicators.ema(candles, indicator.params["period"], indicator.params["source"])
          %{id: indicator.id, type: indicator.type, values: values}
        "rsi" -> 
          values = Indicators.rsi(candles, indicator.params["period"])
          %{id: indicator.id, type: indicator.type, values: values, pane: "separate"}
        # Other indicators...
      end
    end)
  end
  
  # Rest of the helper functions...
end
```

### 3. Results Dashboard (Week 4)
- Create comprehensive performance metrics dashboard
- Implement trade list with filtering and sorting
- Build equity curve visualization
- Develop report generation functionality

**Priority Tasks:**
1. Create performance metrics dashboard
2. Implement trade list with filtering
3. Build equity curve and drawdown charts
4. Develop report export functionality

```elixir
# Sample results dashboard LiveView
defmodule CentralWeb.BacktestLive.Results do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.Backtest
  alias Central.Backtest.Services.Performance
  
  def mount(%{"id" => backtest_id}, _session, socket) do
    backtest = Backtest.get_backtest_with_associations!(backtest_id)
    
    {:ok,
      socket
      |> assign(:backtest, backtest)
      |> assign(:trades, backtest.trades)
      |> assign(:performance, backtest.performance_summary)
      |> assign(:equity_curve, calculate_equity_curve(backtest))
      |> assign(:trade_filters, %{"side" => "all", "result" => "all"})
      |> assign(:trades_page, 1)
      |> assign(:trades_per_page, 20)
    }
  end
  
  def render(assigns) do
    ~H"""
    <div class="container mx-auto py-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Backtest Results: <%= @backtest.strategy.name %></h1>
        <div class="flex space-x-2">
          <.button phx-click="export_report">Export Report</.button>
          <.button phx-click="rerun_backtest">Rerun Backtest</.button>
        </div>
      </div>
      
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-6">
        <.live_component module={CentralWeb.PerformanceCardComponent}
          id="performance-metrics"
          performance={@performance}
        />
        
        <.live_component module={CentralWeb.EquityCurveComponent}
          id="equity-curve"
          equity_curve={@equity_curve}
        />
        
        <.live_component module={CentralWeb.TradeStatisticsComponent}
          id="trade-stats"
          trades={@trades}
        />
      </div>
      
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-semibold">Trades</h2>
          
          <div class="flex space-x-4">
            <div>
              <label class="mr-2">Side:</label>
              <select phx-change="filter_trades" name="side">
                <option value="all">All</option>
                <option value="long">Long</option>
                <option value="short">Short</option>
              </select>
            </div>
            
            <div>
              <label class="mr-2">Result:</label>
              <select phx-change="filter_trades" name="result">
                <option value="all">All</option>
                <option value="win">Winners</option>
                <option value="loss">Losers</option>
              </select>
            </div>
          </div>
        </div>
        
        <.live_component module={CentralWeb.TradeListComponent}
          id="trade-list"
          trades={filter_trades(@trades, @trade_filters)}
          page={@trades_page}
          per_page={@trades_per_page}
        />
      </div>
    </div>
    """
  end
  
  def handle_event("filter_trades", params, socket) do
    filters = Map.take(params, ["side", "result"])
    
    {:noreply,
      socket
      |> assign(:trade_filters, filters)
      |> assign(:trades_page, 1) # Reset to first page when filtering
    }
  end
  
  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply, assign(socket, :trades_page, String.to_integer(page))}
  end
  
  def handle_event("export_report", _params, socket) do
    backtest_id = socket.assigns.backtest.id
    
    # Generate report file
    {:ok, file_path} = Performance.generate_report(backtest_id)
    
    {:noreply,
      socket
      |> put_flash(:info, "Report generated successfully")
      |> push_navigate(to: ~p"/reports/#{Path.basename(file_path)}")
    }
  end
  
  defp calculate_equity_curve(backtest) do
    Performance.calculate_equity_curve(backtest)
  end
  
  defp filter_trades(trades, filters) do
    trades
    |> filter_by_side(filters["side"])
    |> filter_by_result(filters["result"])
  end
  
  defp filter_by_side(trades, "all"), do: trades
  defp filter_by_side(trades, side) when side in ["long", "short"] do
    Enum.filter(trades, &(Atom.to_string(&1.side) == side))
  end
  
  defp filter_by_result(trades, "all"), do: trades
  defp filter_by_result(trades, "win") do
    Enum.filter(trades, &(Decimal.compare(&1.pnl, Decimal.new(0)) == :gt))
  end
  defp filter_by_result(trades, "loss") do
    Enum.filter(trades, &(Decimal.compare(&1.pnl, Decimal.new(0)) in [:lt, :eq]))
  end
end
```

### 4. System Integration (Week 5)
- Implement navigation and flow between components
- Develop user notification system
- Create help and documentation pages
- Build user onboarding process

**Priority Tasks:**
1. Implement application navigation and routing
2. Create user notification system
3. Build help and documentation pages
4. Develop user onboarding flow

```elixir
# Sample app.js with navigation setup
const setupNavigation = () => {
  // Initialize dropdown menus
  document.querySelectorAll('.dropdown-toggle').forEach(toggle => {
    toggle.addEventListener('click', (e) => {
      e.preventDefault();
      const menu = toggle.nextElementSibling;
      menu.classList.toggle('show');
      
      // Close other dropdowns
      document.querySelectorAll('.dropdown-menu.show').forEach(openMenu => {
        if (openMenu !== menu) {
          openMenu.classList.remove('show');
        }
      });
    });
  });
  
  // Close dropdowns when clicking outside
  document.addEventListener('click', (e) => {
    if (!e.target.matches('.dropdown-toggle')) {
      document.querySelectorAll('.dropdown-menu.show').forEach(menu => {
        menu.classList.remove('show');
      });
    }
  });
  
  // Setup mobile menu toggle
  const mobileMenuToggle = document.getElementById('mobile-menu-toggle');
  const mobileMenu = document.getElementById('mobile-menu');
  
  if (mobileMenuToggle && mobileMenu) {
    mobileMenuToggle.addEventListener('click', () => {
      mobileMenu.classList.toggle('hidden');
    });
  }
};

// Initialize tooltips
const setupTooltips = () => {
  document.querySelectorAll('[data-tooltip]').forEach(element => {
    tippy(element, {
      content: element.getAttribute('data-tooltip'),
      placement: element.getAttribute('data-tooltip-placement') || 'top',
      arrow: true,
      animation: 'scale'
    });
  });
};

// Setup notifications
const setupNotifications = () => {
  // Handle notification closing
  document.querySelectorAll('.notification .close').forEach(button => {
    button.addEventListener('click', () => {
      const notification = button.closest('.notification');
      notification.classList.add('fade-out');
      setTimeout(() => {
        notification.remove();
      }, 300);
    });
  });
  
  // Auto-close notifications after timeout
  document.querySelectorAll('.notification.auto-close').forEach(notification => {
    setTimeout(() => {
      notification.classList.add('fade-out');
      setTimeout(() => {
        notification.remove();
      }, 300);
    }, 5000);
  });
};

// Document ready
window.addEventListener('DOMContentLoaded', () => {
  setupNavigation();
  setupTooltips();
  setupNotifications();
});
```

## Testing Strategy
- Write comprehensive tests for UI components
- Implement end-to-end tests for user flows
- Conduct usability testing with sample users
- Validate accessibility compliance

## Expected Deliverables
- Complete strategy configuration interface
- Enhanced interactive charting
- Comprehensive results dashboard
- Integrated navigation and user flow
- User documentation and help system
- Usability test results and improvements

## Next Steps
After completing Stage 3, we will have a fully functional user interface for our backtest system. The next stage will focus on optimization, improving performance, implementing caching, and supporting parallel processing for backtests. 