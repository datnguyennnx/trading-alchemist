defmodule CentralWeb.BacktestLive.ChartLive do
  use CentralWeb, :live_view
  require Logger

  import SaladUI.Card

  # Alias utility modules
  alias CentralWeb.BacktestLive.Utils.DataFormatter
  alias CentralWeb.BacktestLive.Utils.MarketDataLoader

  # Alias component modules
  alias CentralWeb.BacktestLive.Components.ChartStats
  alias CentralWeb.BacktestLive.Components.ChartControls

  # Context aliases used directly in this module
  alias Central.Backtest.Contexts.MarketData, as: MarketDataContext

  def mount(_params, session, socket) do
    # Get available symbols from the context
    symbols = MarketDataLoader.get_symbols()
    default_symbol = "BTCUSDT"
    # Default to 1-hour timeframe
    default_timeframe = "1h"

    # Use theme from session if available, otherwise default to "dark"
    theme = session["theme"] || "dark"

    # Initial state
    socket =
      socket
      |> assign(
        chart_data: [],
        loading: true,
        timeframe: default_timeframe,
        symbol: default_symbol,
        symbols: symbols,
        timeframes: ["1m", "5m", "15m", "1h", "4h", "1d"],
        chart_theme: theme,
        page_title: "Backtest Chart"
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
      <.card>
        <.card_header>
          <.card_title>Backtest Chart</.card_title>
          <.card_description>Visualize your trading strategy performance</.card_description>
        </.card_header>
        <.card_content>
          <div class="h-[500px]">
            <div class="flex flex-col h-full w-full bg-background p-4 gap-4">
              <h1 class="text-2xl font-bold text-foreground">TradingView Chart</h1>

              <div class="flex flex-wrap items-center justify-between gap-3 bg-card rounded-lg p-3 shadow-sm">
                <!-- Market data stats -->
                <ChartStats.chart_stats chart_data={@chart_data} />
                
    <!-- Controls -->
                <ChartControls.chart_controls
                  timeframe={@timeframe}
                  symbol={@symbol}
                  timeframes={@timeframes}
                  symbols={@symbols}
                />
              </div>
              
    <!-- Simplified chart container without overlay elements -->
              <div
                id="tradingview-chart"
                phx-hook="TradingViewChart"
                data-chart-data={Jason.encode!(@chart_data)}
                data-theme={@chart_theme}
                data-symbol={@symbol}
                data-timeframe={@timeframe}
                data-debug={
                  Jason.encode!(%{count: length(@chart_data), timestamp: DateTime.utc_now()})
                }
                class="w-full h-[70vh] rounded-lg border border-border bg-card"
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
          </div>
        </.card_content>
      </.card>
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
      socket =
        push_event(socket, "chart-data-updated", %{
          data: chart_data,
          symbol: socket.assigns.symbol,
          timeframe: socket.assigns.timeframe
        })

      {:noreply, socket}
    else
      # Fetch fresh data
      fresh_data =
        MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

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
    chart_data =
      MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

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
    socket =
      socket
      |> assign(timeframe: timeframe, loading: true)

    send(self(), :load_market_data)
    {:noreply, socket}
  end

  def handle_event("set_symbol", %{"symbol" => symbol}, socket) do
    socket =
      socket
      |> assign(symbol: symbol, loading: true)

    send(self(), :load_market_data)
    {:noreply, socket}
  end

  def handle_event("set_theme", %{"theme" => theme}, socket) do
    socket =
      socket
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
    socket =
      socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  def handle_event("change_theme", %{"theme" => theme}, socket) do
    # Handle theme change from settings dialog
    socket =
      socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  def handle_event(
        "load-historical-data",
        %{"timestamp" => timestamp, "symbol" => symbol, "timeframe" => timeframe} = params,
        socket
      ) do
    # Convert timestamp to DateTime
    earliest_time = DateTime.from_unix!(timestamp)

    # Get batch size from params or use default
    batch_size = Map.get(params, "batchSize", 200)
    # Cap to prevent excessive fetching
    batch_size = min(batch_size, 500)

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

    Logger.info(
      "Fetching historical data for #{symbol}/#{timeframe} from #{DateTime.to_iso8601(start_time)} to #{DateTime.to_iso8601(end_time)} (batch size: #{batch_size})"
    )

    # Fetch historical data
    candles = MarketDataContext.get_candles(symbol, timeframe, start_time, end_time)

    Logger.info("Found #{length(candles)} historical candles")

    # Format the data for the chart
    formatted_data = DataFormatter.format_chart_data(candles)

    # Check if we have data to indicate if more is available
    has_more = length(formatted_data) > 0

    # Optimize batch size for next fetch based on results and timing
    # If we're returning close to the requested amount, we likely have more data
    # If we're returning significantly less, we may be approaching the end of data
    recommended_batch_size =
      cond do
        length(formatted_data) >= batch_size * 0.9 ->
          # Got nearly as many as requested, maintain or increase batch size
          batch_size

        length(formatted_data) >= batch_size * 0.5 ->
          # Getting fewer, maintain batch size
          batch_size

        length(formatted_data) > 0 ->
          # Getting much fewer, reduce batch size
          max(50, trunc(batch_size * 0.7))

        true ->
          # No data, default to small batch size
          100
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

  # Handle loading initial data
  def handle_info(:load_initial_data, socket) do
    chart_data =
      MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

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
    chart_data =
      MarketDataLoader.fetch_market_data(socket.assigns.symbol, socket.assigns.timeframe)

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
end
