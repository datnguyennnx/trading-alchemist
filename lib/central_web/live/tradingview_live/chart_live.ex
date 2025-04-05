defmodule CentralWeb.TradingViewLive.ChartLive do

  use CentralWeb, :live_view
  require Logger

  import Ecto.Query

  # Use the proper contexts and schemas
  alias Central.Backtest.Contexts.MarketData, as: MarketDataContext
  alias Central.Backtest.Schemas.MarketData, as: MarketDataSchema
  alias Central.Backtest.Workers.MarketSync
  alias Central.Repo

  # Import the required components
  import CentralWeb.Components.Button
  import CentralWeb.Components.DropdownMenu
  import CentralWeb.Components.Tooltip
  import CentralWeb.Components.Separator
  import CentralWeb.Components.Icon

  def mount(_params, session, socket) do
    # Get available symbols from the context
    symbols = get_symbols()
    default_symbol = "BTCUSDT"
    default_timeframe = "1h" # Default to 1-hour timeframe

    # Use theme from session if available, otherwise default to "dark"
    theme = session["theme"] || "dark"

    # Initial state
    socket = socket
      |> assign(
        chart_data: [],
        loading: true,
        timeframe: default_timeframe,
        symbol: default_symbol,
        symbols: symbols,
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
    <div class="flex flex-col h-full w-full bg-background p-4 gap-4">

      <h1 class="text-2xl font-bold text-foreground">TradingView Chart</h1>

      <div class="flex flex-wrap items-center justify-between gap-3 bg-card rounded-lg p-3 shadow-sm">
        <!-- Market data stats -->
        <div class="flex items-center gap-3 flex-wrap">
          <div class="flex items-center gap-1">
            <span class="text-xs text-muted-foreground">Open</span>
            <span class="font-medium text-sm"><%= format_price(get_latest_price(@chart_data, :open)) %></span>
          </div>
          <.separator orientation="vertical" class="h-5" />
          <div class="flex items-center gap-1">
            <span class="text-xs text-muted-foreground">High</span>
            <span class="font-medium text-sm text-green-500"><%= format_price(get_latest_price(@chart_data, :high)) %></span>
          </div>
          <.separator orientation="vertical" class="h-5" />
          <div class="flex items-center gap-1">
            <span class="text-xs text-muted-foreground">Low</span>
            <span class="font-medium text-sm text-red-500"><%= format_price(get_latest_price(@chart_data, :low)) %></span>
          </div>
          <.separator orientation="vertical" class="h-5" />
          <div class="flex items-center gap-1">
            <span class="text-xs text-muted-foreground">Close</span>
            <span class="font-medium text-sm"><%= format_price(get_latest_price(@chart_data, :close)) %></span>
          </div>
        </div>

        <!-- Controls -->
        <div class="flex items-center gap-2">
          <.dropdown_menu>
            <.dropdown_menu_trigger class="flex items-center">
              <.button variant="outline" size="sm" class="gap-1 h-8">
                <.icon name="hero-clock" class="h-3.5 w-3.5 mr-1" />
                <span><%= @timeframe %></span>
                <.icon name="hero-chevron-down" class="h-3.5 w-3.5" />
              </.button>
            </.dropdown_menu_trigger>
            <.dropdown_menu_content>
              <div class="py-1.5 text-xs font-medium text-muted-foreground px-2">
                Timeframe
              </div>
              <div class="h-px bg-muted my-1"></div>
              <%= for timeframe <- @timeframes do %>
                <div class="cursor-pointer select-none rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground" phx-click="set_timeframe" phx-value-timeframe={timeframe}><%= timeframe_display(timeframe) %></div>
              <% end %>
            </.dropdown_menu_content>
          </.dropdown_menu>

          <.dropdown_menu>
            <.dropdown_menu_trigger class="flex items-center">
              <.button variant="outline" size="sm" class="gap-1 h-8">
                <.icon name="hero-currency-dollar" class="h-3.5 w-3.5 mr-1" />
                <span><%= @symbol %></span>
                <.icon name="hero-chevron-down" class="h-3.5 w-3.5" />
              </.button>
            </.dropdown_menu_trigger>
            <.dropdown_menu_content>
              <div class="py-1.5 text-xs font-medium text-muted-foreground px-2">
                Symbol
              </div>
              <div class="h-px bg-muted my-1"></div>
              <%= for symbol <- @symbols do %>
                <div class="cursor-pointer select-none rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground" phx-click="set_symbol" phx-value-symbol={symbol}><%= symbol %></div>
              <% end %>
            </.dropdown_menu_content>
          </.dropdown_menu>

          <.tooltip>
            <.tooltip_trigger>
              <.button variant="ghost" size="icon" class="h-8 w-8" phx-click="refresh_data">
                <.icon name="hero-arrow-path" class="h-4 w-4" />
              </.button>
            </.tooltip_trigger>
            <.tooltip_content>
              <p>Refresh Chart</p>
            </.tooltip_content>
          </.tooltip>
        </div>
      </div>

      <!-- Simplified chart container without overlay elements -->
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
    """
  end

  def handle_event("refresh_data", _, socket) do
    send(self(), :load_market_data)
    {:noreply, assign(socket, loading: true)}
  end

  def handle_event("debug_chart", _, socket) do
    # Diagnostic information
    chart_data = socket.assigns.chart_data


    # Generate new data and push it directly to the chart
    if length(chart_data) > 0 do
      # Push the existing data directly to the chart
      socket = push_event(socket, "chart-data-updated", %{
        data: chart_data,
        symbol: socket.assigns.symbol,
        timeframe: socket.assigns.timeframe
      })
      {:noreply, socket}
    else
      # Fetch fresh data
      fresh_data = fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

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

  def handle_event("force_reload", _, socket) do
    # Force a clean mount of the chart
    chart_data = fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)
    Logger.warning("Forcing chart reload with #{length(chart_data)} candles")

    # Push a direct event to update the chart with fresh data
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

  def handle_event("set_timeframe", %{"timeframe" => timeframe}, socket) do
    socket = socket
      |> assign(timeframe: timeframe, loading: true)

    send(self(), :load_market_data)
    {:noreply, socket}
  end

  def handle_event("set_symbol", %{"symbol" => symbol}, socket) do
    socket = socket
      |> assign(symbol: symbol, loading: true)

    send(self(), :load_market_data)
    {:noreply, socket}
  end

  def handle_event("set_theme", %{"theme" => theme}, socket) do
    socket = socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  def handle_event("chart-theme-changed", %{"theme" => theme}, socket) do
    # Update chart theme when changed from chart component
    {:noreply, assign(socket, :chart_theme, theme)}
  end

  def handle_event("theme-changed", %{"theme" => theme}, socket) do
    # Update chart theme when global theme changes
    socket = socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  def handle_event("change_theme", %{"theme" => theme}, socket) do
    # Handle theme change from settings dialog
    socket = socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  # Handle loading initial data
  def handle_info(:load_initial_data, socket) do
    chart_data = fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)
    Logger.info("Initial data load: #{length(chart_data)} candles")

    # Log a sample of the data to help debugging
    if length(chart_data) > 0 do
      first_candle = List.first(chart_data)
      last_candle = List.last(chart_data)
      Logger.debug("First candle in chart_data: #{inspect(first_candle)}")
      Logger.debug("Last candle in chart_data: #{inspect(last_candle)}")
    end

    # Add a brief delay to ensure the chart hook is fully mounted
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

  # Handle loading market data when symbol or timeframe changes
  def handle_info(:load_market_data, socket) do
    chart_data = fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)
    Logger.info("Market data load: #{length(chart_data)} candles")

    # Log a sample of the data to help debugging
    if length(chart_data) > 0 do
      first_candle = List.first(chart_data)
      last_candle = List.last(chart_data)
      Logger.debug("First candle in chart_data: #{inspect(first_candle)}")
      Logger.debug("Last candle in chart_data: #{inspect(last_candle)}")
    end

    # Add a brief delay to ensure the chart hook is fully mounted
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

  # Use the context to get symbols
  defp get_symbols do
    # Try to use the MarketDataContext
    try do
      symbols = MarketDataContext.list_symbols()
      if Enum.empty?(symbols), do: ["BTCUSDT"], else: symbols
    rescue
      # Fall back to query if the context call fails (might be ETS table issues)
      _ ->
        query = from m in MarketDataSchema,
          select: m.symbol,
          distinct: true

        symbols = Repo.all(query) |> Enum.sort()
        if Enum.empty?(symbols), do: ["BTCUSDT"], else: symbols
    end
  end

  # Fetch market data using direct query for reliability
  defp fetch_market_data(symbol, timeframe) do
    # Calculate time range for the last 200 candles
    end_time = DateTime.utc_now()
    start_time = calculate_start_time(end_time, timeframe, 200)

    # Skip the context and use direct query for reliability
    query = from m in MarketDataSchema,
      where: m.symbol == ^symbol,
      where: m.timeframe == ^timeframe,
      where: m.timestamp >= ^start_time,
      where: m.timestamp <= ^end_time,
      order_by: [asc: m.timestamp],
      limit: 200

    candles = Repo.all(query)

    if Enum.empty?(candles) do
      # No data found, trigger a sync for this symbol/timeframe
      Logger.info("No data found for #{symbol}/#{timeframe} - triggering sync")
      try do
        # Trigger market sync for this specific symbol and timeframe
        MarketSync.trigger_sync(symbol, timeframe)
        Logger.info("Sync triggered for #{symbol}/#{timeframe}")

        # Give it a moment to fetch
        :timer.sleep(500)

        # Try one more time
        retried_candles = Repo.all(query)
        if Enum.empty?(retried_candles) do
          Logger.info("Still no data available after sync trigger")
          []
        else
          Logger.info("Found #{length(retried_candles)} candles after sync")
          format_market_data(retried_candles)
        end
      rescue
        e ->
          Logger.error("Failed to trigger sync: #{inspect(e)}")
          []
      end
    else
      # We have data, format it for the chart
      Logger.info("Fetched #{length(candles)} candles for #{symbol}/#{timeframe}")
      if length(candles) > 0 do
        sample = List.first(candles)
        Logger.debug("Sample candle: #{inspect(sample, pretty: true)}")
      end
      format_market_data(candles)
    end
  rescue
    error ->
      Logger.error("Error fetching market data: #{inspect(error, pretty: true)}")
      []  # Return empty list on error
  end

  # Format database data for chart display
  defp format_market_data(candles) do
    # Order by timestamp ascending to ensure proper chart display
    sorted_candles = Enum.sort_by(candles, & &1.timestamp, {:asc, DateTime})

    # Log sample data to debug
    if length(sorted_candles) > 0 do
      first = List.first(sorted_candles)
      last = List.last(sorted_candles)
      Logger.debug("First candle timestamp: #{inspect(first.timestamp)}")
      Logger.debug("Last candle timestamp: #{inspect(last.timestamp)}")
    end

    formatted = Enum.map(sorted_candles, fn candle ->
      time = DateTime.to_unix(candle.timestamp)

      %{
        time: time,  # Ensure this is a Unix timestamp in seconds
        open: to_float(candle.open),
        high: to_float(candle.high),
        low: to_float(candle.low),
        close: to_float(candle.close),
        volume: candle.volume && to_float(candle.volume) || 0.0
      }
    end)

    # Log the formatted data structure
    if length(formatted) > 0 do
      first_formatted = List.first(formatted)
      last_formatted = List.last(formatted)
      Logger.debug("First formatted candle: #{inspect(first_formatted)}")
      Logger.debug("Last formatted candle: #{inspect(last_formatted)}")
      Logger.debug("Total formatted candles: #{length(formatted)}")
    end

    formatted
  end

  # Helper to safely convert Decimal to float
  defp to_float(nil), do: 0.0
  defp to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp to_float(number) when is_number(number), do: number
  defp to_float(_), do: 0.0

  # Calculate start time based on timeframe and candle count
  defp calculate_start_time(end_time, timeframe, count) do
    seconds = case timeframe do
      "1m" -> count * 60
      "5m" -> count * 5 * 60
      "15m" -> count * 15 * 60
      "1h" -> count * 3600
      "4h" -> count * 4 * 3600
      "1d" -> count * 86400
      _ -> count * 3600 # Default to 1h
    end

    DateTime.add(end_time, -seconds, :second)
  end

  # Display formatted timeframe
  defp timeframe_display(timeframe) do
    case timeframe do
      "1m" -> "1 Minute"
      "5m" -> "5 Minutes"
      "15m" -> "15 Minutes"
      "1h" -> "1 Hour"
      "4h" -> "4 Hours"
      "1d" -> "1 Day"
      _ -> timeframe
    end
  end

  # Helper functions for UI display
  defp get_latest_price(chart_data, key) do
    case List.last(chart_data) do
      nil -> nil
      data -> Map.get(data, key)
    end
  end

  defp format_price(nil), do: "--"
  defp format_price(price) when price >= 1000, do: "$#{:erlang.float_to_binary(price, decimals: 2)}"
  defp format_price(price) when price >= 1, do: "$#{:erlang.float_to_binary(price, decimals: 2)}"
  defp format_price(price), do: "$#{:erlang.float_to_binary(price, decimals: 4)}"
end
