defmodule CentralWeb.ChartLive do
  use CentralWeb, :live_view
  alias Phoenix.PubSub

  # Import the required components
  import SaladUI.Button
  import SaladUI.DropdownMenu
  import SaladUI.Tooltip
  import SaladUI.Separator
  import SaladUI.Icon

  def mount(_params, _session, socket) do
    # Subscribe to market data updates
    if connected?(socket) do
      PubSub.subscribe(Central.PubSub, "market_data")
    end

    # Initial state
    {:ok, assign(socket,
      chart_data: fetch_initial_data(),
      timeframe: "1D",
      show_settings: false,
      chart_theme: "dark"
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full w-full bg-background p-4 gap-4">
      <div class="flex flex-row items-center justify-between">
        <h1 class="text-2xl font-bold text-foreground">TradingView Chart</h1>

        <div class="flex items-center gap-2">
          <.dropdown_menu>
            <.dropdown_menu_trigger class="flex items-center">
              <.button variant="outline" size="sm" class="gap-1">
                <span><%= @timeframe %></span>
                <.icon name="hero-chevron-down" class="h-4 w-4" />
              </.button>
            </.dropdown_menu_trigger>
            <.dropdown_menu_content>
              <div class="py-1.5 text-xs font-medium text-muted-foreground px-2">
                Timeframe
              </div>
              <div class="h-px bg-muted my-1"></div>
              <div class="cursor-pointer select-none rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground" phx-click="set_timeframe" phx-value-timeframe="1m">1 Minute</div>
              <div class="cursor-pointer select-none rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground" phx-click="set_timeframe" phx-value-timeframe="5m">5 Minutes</div>
              <div class="cursor-pointer select-none rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground" phx-click="set_timeframe" phx-value-timeframe="15m">15 Minutes</div>
              <div class="cursor-pointer select-none rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground" phx-click="set_timeframe" phx-value-timeframe="1H">1 Hour</div>
              <div class="cursor-pointer select-none rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground" phx-click="set_timeframe" phx-value-timeframe="1D">1 Day</div>
            </.dropdown_menu_content>
          </.dropdown_menu>

          <.tooltip content="Refresh Data">
            <.button phx-click="refresh_data" variant="outline" size="icon">
              <.icon name="hero-arrow-path" class="h-4 w-4" />
            </.button>
          </.tooltip>

          <.tooltip content="Chart Settings">
            <.button phx-click="toggle_settings" variant="outline" size="icon">
              <.icon name="hero-cog-8-tooth" class="h-4 w-4" />
            </.button>
          </.tooltip>
        </div>
      </div>


       <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm mt-2">
        <div class="p-3 rounded-md bg-card">
          <div class="text-muted-foreground mb-1">Open</div>
          <div class="font-medium"><%= format_price(get_latest_price(@chart_data, :open)) %></div>
        </div>
        <div class="p-3 rounded-md bg-card">
          <div class="text-muted-foreground mb-1">High</div>
          <div class="font-medium text-green-500"><%= format_price(get_latest_price(@chart_data, :high)) %></div>
        </div>
        <div class="p-3 rounded-md bg-card">
          <div class="text-muted-foreground mb-1">Low</div>
          <div class="font-medium text-red-500"><%= format_price(get_latest_price(@chart_data, :low)) %></div>
        </div>
      </div>
      <.separator />

      <div
        id="tradingview-chart"
        phx-hook="TradingViewChart"
        data-chart-data={Jason.encode!(@chart_data)}
        data-theme={@chart_theme}
        class="w-full h-[70vh] rounded-lg border border-border bg-card">
      </div>

    </div>
    """
  end

  def handle_event("refresh_data", _, socket) do
    {:noreply, assign(socket, chart_data: fetch_initial_data())}
  end

  def handle_event("set_timeframe", %{"timeframe" => timeframe}, socket) do
    {:noreply, assign(socket, timeframe: timeframe, chart_data: fetch_data_for_timeframe(timeframe))}
  end

  def handle_event("toggle_settings", _, socket) do
    {:noreply, assign(socket, show_settings: !socket.assigns.show_settings)}
  end

  def handle_event("close_settings", _, socket) do
    {:noreply, assign(socket, show_settings: false)}
  end

  def handle_event("set_theme", %{"theme" => theme}, socket) do
    # Update theme and push event to JS hook
    socket = socket
      |> assign(:chart_theme, theme)
      |> push_event("chart-theme-updated", %{theme: theme})

    {:noreply, socket}
  end

  def handle_event("apply_settings", _, socket) do
    # Apply settings logic here - in a real app, you might update the chart via JS hooks
    {:noreply, assign(socket, show_settings: false)}
  end

  def handle_info({:update_chart, new_data}, socket) do
    {:noreply, push_event(socket, "chart-data-updated", %{data: new_data})}
  end

  defp fetch_initial_data do
    # This would fetch your initial trading data
    # For demonstration, we'll generate sample data
    generate_sample_candlestick_data(100)
  end

  defp fetch_data_for_timeframe(timeframe) do
    # In a real app, you would fetch data for the specific timeframe
    # For now, we'll generate different amounts of data based on timeframe
    points = case timeframe do
      "1D" -> 30
      "1H" -> 60
      "15m" -> 120
      "5m" -> 180
      "1m" -> 240
      _ -> 100
    end

    generate_sample_candlestick_data(points)
  end

  defp generate_sample_candlestick_data(count) do
    # Generate realistic sample data for candlestick chart
    now = DateTime.utc_now()
    base_price = 100.0

    Enum.map(0..(count - 1), fn i ->
      # Create timestamp (seconds)
      time = now
        |> DateTime.add(-i * 3600, :second)
        |> DateTime.to_unix()

      # Random price movement
      random_factor = :rand.normal(0, 1) * 2
      open = base_price + random_factor

      # Create volatility
      high = open + :rand.uniform() * 5
      low = open - :rand.uniform() * 5

      # Create trend
      close_direction = :rand.normal(0, 1)
      close = open + close_direction * :rand.uniform() * 3

      # Ensure high is highest and low is lowest
      high = max(high, max(open, close))
      low = min(low, min(open, close))

      # Update base price for next iteration
      base_price = close + :rand.normal(0.01, 0.1)

      # Return data point
      %{
        time: time,
        open: Float.round(open, 2),
        high: Float.round(high, 2),
        low: Float.round(low, 2),
        close: Float.round(close, 2)
      }
    end)
    |> Enum.reverse()  # Reverse to get chronological order
  end

  # Helper functions for UI display
  defp get_latest_price(chart_data, key) do
    case List.last(chart_data) do
      nil -> nil
      data -> Map.get(data, key)
    end
  end

  defp format_price(nil), do: "--"
  defp format_price(price), do: "$#{:erlang.float_to_binary(price, decimals: 2)}"
end
