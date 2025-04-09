defmodule CentralWeb.BacktestLive.ShowLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext
  alias Central.Backtest.Contexts.BacktestContext
  alias Central.Backtest.Contexts.TradeContext

  # Add necessary imports
  import SaladUI.Button
  import SaladUI.Card
  import SaladUI.Accordion
  import SaladUI.Table

  # Add necessary aliases for the chart
  alias CentralWeb.BacktestLive.Utils.DataFormatter
  alias CentralWeb.BacktestLive.Utils.MarketDataLoader
  alias CentralWeb.BacktestLive.Components.ChartStats
  alias CentralWeb.BacktestLive.Components.ChartControls

  def mount(%{"strategy_id" => strategy_id}, session, socket) do
    strategy = StrategyContext.get_strategy!(strategy_id)

    # Get all backtests for the strategy with preloaded trades
    # Use Repo.preload to efficiently load all trades at once
    backtests =
      BacktestContext.list_backtests_for_strategy(strategy_id)
      |> Enum.map(fn backtest ->
        trades = TradeContext.list_trades_for_backtest(backtest.id)
        # Log the number of trades found for debugging
        IO.puts("Loaded #{length(trades)} trades for backtest #{backtest.id}")
        Map.put(backtest, :trades, trades)
      end)

    # Log the number of backtests found for debugging
    IO.puts("Loaded #{length(backtests)} backtests for strategy #{strategy_id}")

    # Get initial backtest (most recent one or nil)
    backtest = List.first(backtests)

    # Get symbol and timeframe from strategy
    symbol = strategy.config["symbol"] || "BTCUSDT"
    timeframe = strategy.config["timeframe"] || "1h"

    # Use theme from session if available, otherwise default to "dark"
    theme = session["theme"] || "dark"

    socket = socket
      |> assign(:strategy, strategy)
      |> assign(:backtests, backtests)
      |> assign(:backtest, backtest)
      |> assign(:page_title, "Backtest: #{strategy.name}")
      |> assign(
        chart_data: [],
        loading: true,
        timeframe: timeframe,
        symbol: symbol,
        symbols: MarketDataLoader.get_symbols(),
        timeframes: ["1m", "5m", "15m", "1h", "4h", "1d"],
        chart_theme: theme
      )

    # Load data immediately for the initial view
    if connected?(socket) do
      Process.send_after(self(), :load_initial_data, 300)
    end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold">Backtest: <%= @strategy.name %></h1>
          <p class="text-muted-foreground mt-1"><%= @strategy.description %></p>
        </div>
        <div class="flex space-x-3">
          <.button phx-click="debug_backtests" variant="outline" class="mr-2">
            Refresh Backtests
          </.button>
          <.link navigate={~p"/strategies/#{@strategy.id}"}>
            <.button variant="outline">Strategy Details</.button>
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-4 gap-8">
        <div class="lg:col-span-3">
          <div class="bg-background rounded-lg border border-border p-4">
            <div class="h-[500px]">
              <div class="flex flex-col h-full w-full bg-background p-4 gap-4">
                <!-- Market data stats -->
                <ChartStats.chart_stats chart_data={@chart_data} />

                <!-- Chart container -->
                <div
                  id="tradingview-chart"
                  phx-hook="TradingViewChart"
                  data-chart-data={Jason.encode!(@chart_data)}
                  data-theme={@chart_theme}
                  data-symbol={@symbol}
                  data-timeframe={@timeframe}
                  data-debug={Jason.encode!(%{count: length(@chart_data), timestamp: DateTime.utc_now()})}
                  class="w-full h-[70vh] rounded-lg border border-border bg-card"
                  phx-update="ignore"
                  style="position: relative;"
                >
                  <div class="h-full w-full flex items-center justify-center">
                    <p id="loading-text" class="text-muted-foreground">
                      <%= if @loading, do: "Loading market data...", else: "Chart will render here" %>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Backtests and Trades Accordion -->
          <div class="mt-8">
            <h2 class="text-xl font-semibold mb-4">Backtest History</h2>
            <%= if Enum.empty?(@backtests) do %>
              <div class="bg-card rounded-md p-6 border border-border text-center">
                <h3 class="text-lg font-medium mb-2">No Backtests Found</h3>
                <p class="text-muted-foreground mb-4">
                  Use the form on the right to create your first backtest for this strategy.
                </p>
              </div>
            <% else %>
              <.accordion>
                <%= for backtest <- @backtests do %>
                  <.accordion_item>
                    <.accordion_trigger group="backtests">
                      <div class="flex justify-between w-full">
                        <span><%= format_datetime(backtest.inserted_at) %></span>
                        <span class="flex items-center">
                          <span class="mr-2 px-2 py-1 rounded-md text-xs">
                            <span class={status_color(backtest.status)}><%= String.upcase(to_string(backtest.status)) %></span>
                          </span>
                          <span class="text-muted-foreground">
                            <%= backtest.symbol %> / <%= backtest.timeframe %>
                          </span>
                        </span>
                      </div>
                    </.accordion_trigger>
                    <.accordion_content>
                      <div class="bg-card rounded-md p-4 mb-4">
                        <div class="grid grid-cols-2 gap-4 mb-4">
                          <div>
                            <p class="text-sm text-muted-foreground">Initial Balance</p>
                            <p class="font-semibold"><%= backtest.initial_balance %> USDT</p>
                          </div>
                          <div>
                            <p class="text-sm text-muted-foreground">Final Balance</p>
                            <p class="font-semibold"><%= backtest.final_balance || "N/A" %> USDT</p>
                          </div>
                          <div>
                            <p class="text-sm text-muted-foreground">Start Time</p>
                            <p class="font-semibold"><%= format_datetime(backtest.start_time) %></p>
                          </div>
                          <div>
                            <p class="text-sm text-muted-foreground">End Time</p>
                            <p class="font-semibold"><%= format_datetime(backtest.end_time) %></p>
                          </div>
                        </div>

                        <!-- Trades using Table component -->
                        <h3 class="text-md font-semibold mb-2">Trades</h3>
                        <%= if Enum.empty?(backtest.trades) do %>
                          <p class="text-muted-foreground">No trades for this backtest</p>
                        <% else %>
                          <.table>
                            <.table_header>
                              <.table_row>
                                <.table_head>Entry Time</.table_head>
                                <.table_head>Side</.table_head>
                                <.table_head>Entry Price</.table_head>
                                <.table_head>Exit Price</.table_head>
                                <.table_head>PnL</.table_head>
                                <.table_head>PnL %</.table_head>
                              </.table_row>
                            </.table_header>
                            <.table_body>
                              <%= for trade <- backtest.trades do %>
                                <.table_row>
                                  <.table_cell><%= format_datetime(trade.entry_time) %></.table_cell>
                                  <.table_cell class={side_color(trade.side)}><%= trade.side %></.table_cell>
                                  <.table_cell><%= trade.entry_price %></.table_cell>
                                  <.table_cell><%= trade.exit_price %></.table_cell>
                                  <.table_cell class={pnl_color(trade.pnl)}><%= trade.pnl %></.table_cell>
                                  <.table_cell class={pnl_color(trade.pnl_percentage)}><%= format_percentage(trade.pnl_percentage) %></.table_cell>
                                </.table_row>
                              <% end %>
                            </.table_body>
                          </.table>
                        <% end %>
                      </div>
                    </.accordion_content>
                  </.accordion_item>
                <% end %>
              </.accordion>
            <% end %>
          </div>
        </div>

        <div>
          <.live_component
            module={CentralWeb.BacktestLive.Components.BacktestConfig}
            id="backtest-config"
            strategy={@strategy}
            backtest={@backtest}
          />
        </div>
      </div>
    </div>
    """
  end

  def handle_event("refresh_data", _, socket) do
    send(self(), :load_market_data)
    {:noreply, assign(socket, loading: true)}
  end

  def handle_event("debug_chart", _, socket) do
    # Push the existing data directly to the chart
    if length(socket.assigns.chart_data) > 0 do
      socket = push_event(socket, "chart-data-updated", %{
        data: socket.assigns.chart_data,
        symbol: socket.assigns.symbol,
        timeframe: socket.assigns.timeframe
      })
      {:noreply, socket}
    else
      # Fetch fresh data
      fresh_data = MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)
      socket =
        socket
        |> assign(chart_data: fresh_data)
        |> push_event("chart-data-updated", %{
          data: fresh_data,
          symbol: socket.assigns.symbol,
          timeframe: socket.assigns.timeframe
        })
      {:noreply, socket}
    end
  end

  def handle_event("set_theme", %{"theme" => theme}, socket) do
    socket = socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})
    {:noreply, socket}
  end

  def handle_event("load-historical-data", %{"timestamp" => timestamp, "symbol" => symbol, "timeframe" => timeframe, "batchSize" => batch_size}, socket) do
    # Convert timestamp to DateTime
    earliest_time = DateTime.from_unix!(timestamp)

    # Calculate start and end times for fetching historical data
    timeframe_seconds = case timeframe do
      "1m" -> 60
      "5m" -> 5 * 60
      "15m" -> 15 * 60
      "1h" -> 3600
      "4h" -> 4 * 3600
      "1d" -> 86400
      _ -> 3600 # Default to 1h
    end

    # Calculate time needed to fetch earlier candles
    fetch_duration = timeframe_seconds * batch_size
    start_time = DateTime.add(earliest_time, -fetch_duration, :second)
    end_time = earliest_time

    # Fetch historical data using MarketDataLoader
    candles = MarketDataLoader.fetch_historical_data(symbol, timeframe, start_time, end_time)

    # Format the data for the chart
    formatted_data = candles

    # Check if we have data to indicate if more is available
    has_more = length(formatted_data) > 0

    # Optimize batch size for next fetch based on results
    recommended_batch_size = cond do
      length(formatted_data) >= batch_size * 0.9 -> batch_size
      length(formatted_data) >= batch_size * 0.5 -> batch_size
      length(formatted_data) > 0 -> max(50, trunc(batch_size * 0.7))
      true -> 100
    end

    # Send the data back to the client
    socket = push_event(socket, "chart-data-updated", %{
      data: formatted_data,
      symbol: symbol,
      timeframe: timeframe,
      append: true # Indicate this is an append operation
    })

    # Return value to JavaScript pushEvent using {:reply, value, socket}
    {:reply, %{
      has_more: has_more,
      batchSize: recommended_batch_size
    }, socket}
  end

  def handle_info({:backtest_update, backtest}, socket) do
    {:noreply, assign(socket, :backtest, backtest)}
  end

  # Handle loading initial data
  def handle_info(:load_initial_data, socket) do
    chart_data = MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

    socket =
      socket
      |> assign(chart_data: chart_data, loading: false)
      |> push_event("chart-data-updated", %{
        data: chart_data,
        symbol: socket.assigns.symbol,
        timeframe: socket.assigns.timeframe
      })

    {:noreply, socket}
  end

  # Handle loading market data when needed
  def handle_info(:load_market_data, socket) do
    chart_data = MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

    socket =
      socket
      |> assign(chart_data: chart_data, loading: false)
      |> push_event("chart-data-updated", %{
        data: chart_data,
        symbol: socket.assigns.symbol,
        timeframe: socket.assigns.timeframe
      })

    {:noreply, socket}
  end

  def handle_event("debug_backtests", _, socket) do
    strategy_id = socket.assigns.strategy.id

    # Try again to load backtests directly
    backtests = BacktestContext.list_backtests_for_strategy(strategy_id)

    # Log results
    IO.puts("DEBUG: Found #{length(backtests)} backtests for strategy #{strategy_id}")

    # For each backtest, try to load trades
    backtests_with_trades = Enum.map(backtests, fn backtest ->
      trades = TradeContext.list_trades_for_backtest(backtest.id)
      IO.puts("DEBUG: Found #{length(trades)} trades for backtest #{backtest.id}")
      Map.put(backtest, :trades, trades)
    end)

    {:noreply,
      socket
      |> assign(:backtests, backtests_with_trades)
      |> put_flash(:info, "Refreshed backtests: Found #{length(backtests)}")
    }
  end

  # Helper functions for formatting and styling
  defp format_datetime(nil), do: "N/A"
  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  defp format_percentage(nil), do: "N/A"
  defp format_percentage(decimal) do
    "#{decimal}%"
  end

  defp status_color(status) do
    case status do
      :completed -> "bg-green-100 text-green-800"
      :running -> "bg-blue-100 text-blue-800"
      :pending -> "bg-yellow-100 text-yellow-800"
      :failed -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp side_color(side) do
    case side do
      :long -> "text-green-600"
      :short -> "text-red-600"
      _ -> ""
    end
  end

  defp pnl_color(nil), do: ""
  defp pnl_color(value) do
    cond do
      Decimal.compare(value, Decimal.new(0)) == :gt -> "text-green-600"
      Decimal.compare(value, Decimal.new(0)) == :lt -> "text-red-600"
      true -> ""
    end
  end
end
