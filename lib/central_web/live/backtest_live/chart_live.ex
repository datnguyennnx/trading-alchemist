defmodule CentralWeb.BacktestLive.ChartLive do
  use CentralWeb, :live_view
  require Logger

  import CentralWeb.Components.UI.Card

  # Alias our new chart components
  alias CentralWeb.Live.Components.Chart.{ChartDataManager, BacktestChartComponent}
  alias Central.Backtest.Contexts.MarketDataContext

  @impl true
  def mount(_params, session, socket) do
    # Get available symbols and timeframes
    available_symbols = MarketDataContext.get_available_symbols()
    available_timeframes = MarketDataContext.get_available_timeframes()

    # Use theme from session if available, otherwise default to "dark"
    theme = session["theme"] || "light"

    # Initial state
    socket =
      socket
      |> assign(
        symbol: "BTCUSDT",
        timeframe: "1h",
        available_symbols: available_symbols,
        available_timeframes: available_timeframes,
        chart_theme: theme,
        page_title: "Backtest Chart"
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <.card>
        <.card_header>
          <.card_title>Backtest Chart</.card_title>
          <.card_description>Visualize your trading strategy performance</.card_description>
        </.card_header>
        <.card_content>
          <.live_component
            module={BacktestChartComponent}
            id="backtest-chart"
            symbol={@symbol}
            timeframe={@timeframe}
            theme={@chart_theme}
            height="70vh"
          />
        </.card_content>
      </.card>
    </div>
    """
  end

  # Event handlers for parent LiveView
  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) do
    socket =
      socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  @impl true
  def handle_event("chart-theme-changed", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :chart_theme, theme)}
  end

  @impl true
  def handle_event("theme-changed", %{"theme" => theme}, socket) do
    socket =
      socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  @impl true
  def handle_event(
    "load-historical-data",
    %{"timestamp" => timestamp, "symbol" => symbol, "timeframe" => timeframe} = params,
    socket
  ) do
    batch_size = Map.get(params, "batchSize", 200)
    result = ChartDataManager.load_historical_data(symbol, timeframe, timestamp, batch_size: batch_size)

    socket = push_event(socket, "chart-data-updated", %{
      data: result.data,
      symbol: symbol,
      timeframe: timeframe,
      append: true
    })

    {:reply, %{
      has_more: result.has_more,
      batchSize: result.recommended_batch_size
    }, socket}
  end

  @impl true
  def handle_info({:chart_set_timeframe, %{timeframe: timeframe}}, socket) do
    {:noreply, assign(socket, :timeframe, timeframe)}
  end

  @impl true
  def handle_info({:chart_set_symbol, %{symbol: symbol}}, socket) do
    {:noreply, assign(socket, :symbol, symbol)}
  end
end
