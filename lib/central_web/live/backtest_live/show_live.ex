defmodule CentralWeb.BacktestLive.ShowLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext
  alias Central.Backtest.Contexts.BacktestContext
  alias Central.Backtest.Contexts.TradeContext

  # Add necessary imports
  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Accordion
  import CentralWeb.Components.UI.DataTable, except: [status_color: 1]

  # Add necessary aliases for the chart
  alias CentralWeb.BacktestLive.Utils.MarketDataLoader
  alias CentralWeb.BacktestLive.Components.ChartStats

  @impl true
  def mount(%{"strategy_id" => strategy_id}, session, socket) do
    strategy = StrategyContext.get_strategy!(strategy_id)

    # Get all backtests for the strategy
    backtests =
      BacktestContext.list_backtests_for_strategy(strategy_id)
      |> Enum.map(fn backtest ->
        # Get total count for pagination
        total_trades = TradeContext.count_trades_for_backtest(backtest.id)

        # Get trades for just the first page
        trades = TradeContext.list_trades_for_backtest_paginated(backtest.id, 1, 50)

        # Store trades and total count in the backtest map
        backtest
        |> Map.put(:trades, trades)
        |> Map.put(:total_trades, total_trades)
      end)

    # Get initial backtest (most recent one or nil)
    backtest = List.first(backtests)

    # Get symbol and timeframe from strategy
    symbol = strategy.config["symbol"] || "BTCUSDT"
    timeframe = strategy.config["timeframe"] || "1h"

    # Use theme from session if available, otherwise default to "dark"
    theme = session["theme"] || "dark"

    socket =
      socket
      |> assign(:strategy, strategy)
      |> assign(:backtests, backtests)
      |> assign(:backtest, backtest)
      |> assign(:page_title, "Backtest: #{strategy.name}")
      |> assign(:page_size, 50) # Default page size for trade tables
      |> assign(
        chart_data: [],
        loading: true,
        timeframe: timeframe,
        symbol: symbol,
        symbols: MarketDataLoader.get_symbols(),
        timeframes: ["1m", "5m", "15m", "1h", "4h", "1d"],
        chart_theme: theme,
        trade_pages: %{}, # Map to store current page for each backtest
        open_accordions: %{}, # Map to track which accordion items are open
        selected_trades_map: %{} # NEW: Map to store selected trades per backtest id
      )

    # Load data immediately for the initial view
    if connected?(socket) do
      Process.send_after(self(), :load_initial_data, 300)
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 w-full">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold">Backtest: {@strategy.name}</h1>
          <p class="text-muted-foreground mt-1">{@strategy.description}</p>
        </div>
        <div class="flex space-x-3">
          <.button phx-click="refresh_backtests" variant="outline" class="mr-2">
            Refresh
          </.button>
          <.link navigate={~p"/strategies/#{@strategy.id}"}>
            <.button variant="outline">Strategy Details</.button>
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
        <div class="lg:col-span-3">
          <div class="bg-background rounded-lg border border-border p-4 flex flex-col">
            <div class="mb-4">
              <ChartStats.chart_stats chart_data={@chart_data} />
            </div>

            <div
              id="tradingview-chart"
              phx-hook="TradingViewChart"
              data-chart-data={Jason.encode!(@chart_data)}
              data-theme={@chart_theme}
              data-symbol={@symbol}
              data-timeframe={@timeframe}
              class="w-full h-[50vh] rounded-lg border border-border bg-card flex-grow"
              phx-update="ignore"
              style="position: relative;"
            >
              <div class="h-full w-full flex items-center justify-center">
                <p id="loading-text" class="text-muted-foreground">
                  {if @loading, do: "Loading market data...", else: "Chart will render here"}
                </p>
              </div>
            </div>
          </div>

          <div class="mt-6">
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
                    <.accordion_trigger
                      group="backtests"
                      open={Map.get(@open_accordions, backtest.id, false)}
                      phx-click="toggle_accordion"
                      phx-value-backtest_id={backtest.id}
                    >
                      <div class="flex justify-between items-center w-full">
                        <span class="text-sm font-medium">{format_datetime(backtest.inserted_at)}</span>
                        <span class="flex items-center space-x-2 mx-2">
                          <span
                            class={"px-2 py-0.5 rounded text-xs font-medium #{status_color(backtest.status)}"}
                          >
                            {String.upcase(to_string(backtest.status))}
                          </span>
                          <span class="text-sm text-muted-foreground">
                            {backtest.symbol} / {backtest.timeframe}
                          </span>
                        </span>
                      </div>
                    </.accordion_trigger>
                    <.accordion_content>
                      <%!-- Only render content if the accordion item is open --%>
                      <%= if Map.get(@open_accordions, backtest.id, false) do %>
                        <div class="bg-card">
                          <div class="grid grid-cols-2 gap-4 mb-4">
                            <div>
                              <p class="text-sm text-muted-foreground">Initial Balance</p>
                              <p class="font-semibold">{backtest.initial_balance} USDT</p>
                            </div>
                            <div>
                              <p class="text-sm text-muted-foreground">Final Balance</p>
                              <p class="font-semibold">{backtest.final_balance || "N/A"} USDT</p>
                            </div>
                            <div>
                              <p class="text-sm text-muted-foreground">Start Time</p>
                              <p class="font-semibold">{format_datetime(backtest.start_time)}</p>
                            </div>
                            <div>
                              <p class="text-sm text-muted-foreground">End Time</p>
                              <p class="font-semibold">{format_datetime(backtest.end_time)}</p>
                            </div>
                            <%= if backtest.status == :completed do %>
                              <div>
                                <p class="text-sm text-muted-foreground">Total Trades</p>
                                <p class="font-semibold">{backtest.total_trades || "N/A"}</p>
                              </div>
                            <% end %>
                          </div>

                          <%= if Enum.empty?(backtest.trades) do %>
                            <p class="text-muted-foreground">No trades for this backtest</p>
                          <% else %>
                            <%!-- Explicitly create the table ID --%>
                            <% table_id = "trades-table-#{backtest.id}" %>
                            <.data_table
                              id={table_id}
                              rows={backtest.trades}
                              row_id={fn trade -> trade.id end}
                              row_numbers
                              selectable
                              selected_rows={@selected_trades_map[backtest.id] || []}
                              page={@trade_pages[backtest.id] || 1}
                              page_size={@page_size}
                              total_entries={backtest.total_trades}
                              on_page_change="trade_page_changed"
                              on_select="select_trade"
                              phx_value_keys={%{backtest_id: backtest.id}}
                            >
                              <:col :let={trade} field={:entry_time} label="Entry Time">
                                {format_datetime(trade.entry_time)}
                              </:col>
                              <:col :let={trade} field={:side} label="Side">
                                <span class={side_color(trade.side)}>{trade.side}</span>
                              </:col>
                              <:col :let={trade} field={:entry_price} label="Entry Price" numeric>
                                {trade.entry_price}
                              </:col>
                              <:col :let={trade} field={:exit_price} label="Exit Price" numeric>
                                {trade.exit_price}
                              </:col>
                              <:col :let={trade} field={:pnl} label="PnL" numeric pnl>
                                <span class={pnl_color(trade.pnl)}>{trade.pnl}</span>
                              </:col>
                              <:col :let={trade} field={:pnl_percentage} label="PnL %" numeric pnl>
                                <span class={pnl_color(trade.pnl_percentage)}>
                                  {format_percentage(trade.pnl_percentage)}
                                </span>
                              </:col>
                            </.data_table>
                          <% end %>
                        </div>
                      <% end %>
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

  @impl true
  def handle_event("refresh_data", _, socket) do
    send(self(), :load_market_data)
    {:noreply, assign(socket, loading: true)}
  end

  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) do
    socket =
      socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_backtests", _, socket) do
    strategy_id = socket.assigns.strategy.id

    # Get backtests directly
    backtests = BacktestContext.list_backtests_for_strategy(strategy_id)

    # Load trades for each backtest
    backtests_with_trades =
      Enum.map(backtests, fn backtest ->
        trades = TradeContext.list_trades_for_backtest(backtest.id)
        total_trades = length(trades)
        IO.inspect(%{backtest_id: backtest.id, total_trades: total_trades}, label: "[Refresh] Total trades count")

        backtest
        |> Map.put(:trades, trades)
        |> Map.put(:total_trades, total_trades)
      end)

    {:noreply,
     socket
     |> assign(:backtests, backtests_with_trades)
     |> put_flash(:info, "Refreshed backtests: Found #{length(backtests)}")}
  end

  @impl true
  def handle_event("cancel", _, socket) do
    {:noreply,
     socket
     |> redirect(to: ~p"/strategies/#{socket.assigns.strategy.id}")}
  end

  @impl true
  def handle_event("load-historical-data", params, socket) do
    # Extract parameters with defaults to handle any structure
    timestamp = params["timestamp"]
    symbol = params["symbol"] || socket.assigns.symbol
    timeframe = params["timeframe"] || socket.assigns.timeframe
    batch_size = params["batchSize"] || 200

    # Convert timestamp to DateTime
    earliest_time = try do
      DateTime.from_unix!(timestamp)
    rescue
      _ -> DateTime.utc_now()
    end

    # Calculate start and end times for fetching historical data
    timeframe_seconds =
      case timeframe do
        "1m" -> 60
        "5m" -> 5 * 60
        "15m" -> 15 * 60
        "1h" -> 3600
        "4h" -> 4 * 3600
        "1d" -> 86400
        # Default to 1h
        _ -> 3600
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
    recommended_batch_size =
      cond do
        length(formatted_data) >= batch_size * 0.9 -> batch_size
        length(formatted_data) >= batch_size * 0.5 -> batch_size
        length(formatted_data) > 0 -> max(50, trunc(batch_size * 0.7))
        true -> 100
      end

    # Send the data back to the client
    socket =
      push_event(socket, "chart-data-updated", %{
        data: formatted_data,
        symbol: symbol,
        timeframe: timeframe,
        # Indicate this is an append operation
        append: true
      })

    # Return value to JavaScript pushEvent using {:reply, value, socket}
    {:reply,
     %{
       has_more: has_more,
       batchSize: recommended_batch_size
     }, socket}
  end

  @impl true
  def handle_event("trade_page_changed", %{"page" => page} = params, socket) do
    # Extract backtest_id (string UUID)
    backtest_id = params["backtest_id"]

    if backtest_id do
      # Use page_size from assigns
      page_size = socket.assigns.page_size

      # Fetch only the trades for this page
      trades = TradeContext.list_trades_for_backtest_paginated(backtest_id, page, page_size)

      # Update the backtest in the socket with the new trades
      updated_backtests = Enum.map(socket.assigns.backtests, fn backtest ->
        if backtest.id == backtest_id do
          Map.put(backtest, :trades, trades)
        else
          backtest
        end
      end)

      # Make sure the accordion stays open when changing pages
      open_accordions = Map.put(socket.assigns.open_accordions, backtest_id, true)

      {:noreply,
        socket
        |> assign(:backtests, updated_backtests)
        |> assign(:trade_pages, Map.put(socket.assigns.trade_pages, backtest_id, page))
        |> assign(:open_accordions, open_accordions)}
    else
      # If we can't find a backtest_id, just acknowledge the event
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_trade", %{"select" => trade_id_str, "backtest_id" => backtest_id}, socket) do
    selected_map = socket.assigns.selected_trades_map
    current_selection = Map.get(selected_map, backtest_id, [])

    new_selection =
      if trade_id_str in current_selection do
        List.delete(current_selection, trade_id_str)
      else
        [trade_id_str | current_selection]
      end

    new_selected_map = Map.put(selected_map, backtest_id, new_selection)

    {:noreply, assign(socket, :selected_trades_map, new_selected_map)}
  end

  @impl true
  def handle_event("select_trade", %{"select_all" => "toggle", "backtest_id" => backtest_id}, socket) do
    # backtest_id is the correct string UUID, no parsing needed

    selected_map = socket.assigns.selected_trades_map
    current_selection = Map.get(selected_map, backtest_id, [])

    # Find the current backtest's structure from assigns using string ID
    current_backtest = Enum.find(socket.assigns.backtests, fn b -> b.id == backtest_id end)

    # Get IDs of all trades currently displayed for THIS BACKTEST PAGE
    all_current_trade_ids =
      if current_backtest do
        Enum.map(current_backtest.trades, &(&1.id))
      else
        []
      end

    all_selected? = Enum.all?(all_current_trade_ids, fn id -> id in current_selection end)

    new_selection =
      if all_selected? do
        # Remove the current page's trade IDs from the selection
        Enum.reject(current_selection, fn id -> id in all_current_trade_ids end)
      else
        # Add all current trade IDs to the selection (avoiding duplicates)
        Enum.uniq(current_selection ++ all_current_trade_ids)
      end

    new_selected_map = Map.put(selected_map, backtest_id, new_selection)

    {:noreply, assign(socket, :selected_trades_map, new_selected_map)}
  end

  @impl true
  def handle_event("toggle_accordion", %{"backtest_id" => backtest_id}, socket) do
    # Toggle the open state of this accordion
    open_accordions = socket.assigns.open_accordions
    is_open = Map.get(open_accordions, backtest_id, false)

    # Update the open state map
    new_open_accordions = Map.put(open_accordions, backtest_id, !is_open)

    {:noreply, assign(socket, :open_accordions, new_open_accordions)}
  end

  @impl true
  def handle_info({:backtest_update, backtest}, socket) do
    {:noreply, assign(socket, :backtest, backtest)}
  end

  @impl true
  def handle_info(:load_initial_data, socket) do
    chart_data =
      MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

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

  @impl true
  def handle_info(:load_market_data, socket) do
    chart_data =
      MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

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
