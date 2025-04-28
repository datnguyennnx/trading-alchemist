defmodule CentralWeb.Live.Components.Chart.ChartComponent do
  use Phoenix.LiveComponent

  # Removed incorrect import of Phoenix.LiveView
  import CentralWeb.Components.UI.Icon

  require Logger

  # Chart type determines if it expects backtest data (all at once) or generic (initial + potential updates)
  attr :chart_type, :atom,
    required: true,
    values: [:generic, :backtest],
    doc: "Indicates the type of data handling expected."

  attr :chart_id, :string,
    required: true,
    doc: "Unique ID for the chart element and JS Hook targeting."

  attr :symbol, :string, required: true, doc: "The trading symbol (e.g., BTCUSDT)."
  attr :timeframe, :string, required: true, doc: "The chart timeframe (e.g., 1h)."
  attr :theme, :string, default: "light", doc: "Chart theme ('light' or 'dark')."
  attr :height, :string, default: "500px", doc: "Chart container height."
  # Optional start/end time limits, mainly for backtest or specific historical views
  attr :start_time_limit, DateTime, default: nil, doc: "Optional earliest data timestamp limit."
  attr :end_time_limit, DateTime, default: nil, doc: "Optional latest data timestamp limit."
  # Loading state controlled by the parent
  attr :loading, :boolean,
    default: true,
    doc: "Indicates if the parent is currently loading data."

  # Chart data directly passed by parent
  attr :chart_data, :list, default: [], doc: "OHLC candle data for chart."
  # Options passed directly to the JS hook (e.g., trade markers for backtest)
  attr :opts, :map, default: %{}, doc: "Additional options passed to the JS hook."

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(chart_id: nil)
     |> assign(loading: true)
     |> assign(chart_data: [])
     |> assign(opts: %{})
     |> assign(data_pushed: false)}
  end

  @impl true
  def update(assigns, socket) do
    # Check if this is a data push request, triggered by chart-initialized or parent
    if Map.get(assigns, :push_data, false) do
      # IO.puts("--- UPDATE TRIGGERED BY PUSH_DATA=TRUE ---")
      socket =
        if !Enum.empty?(socket.assigns.chart_data) do
          Logger.debug("Pushing initial data event: #{socket.assigns.chart_id}")
          # IO.puts("--- CHART DATA PUSH (via push_event) ---") # Changed log message
          # IO.inspect(socket.assigns.chart_id, label: "Chart ID")
          # IO.inspect(length(socket.assigns.chart_data), label: "Number of candles pushed")
          # IO.inspect(socket.assigns.opts[:trades] && length(socket.assigns.opts[:trades]), label: "Number of trades pushed")

          # Revert to using push_event
          push_event(socket, "set-initial-data", %{
            chartId: socket.assigns.chart_id,
            data: socket.assigns.chart_data,
            # Sending opts again
            opts: socket.assigns.opts
          })
        else
          # IO.puts("--- CHART DATA PUSH SKIPPED (EMPTY DATA) ---")
          # IO.inspect(socket.assigns.chart_id, label: "Chart ID")
          Logger.debug("Chart data push skipped (empty data): #{socket.assigns.chart_id}")
          socket
        end

      # Mark data as pushed after attempting
      {:ok, assign(socket, :data_pushed, true)}
    else
      # Default update: Assign incoming assigns
      # IO.puts("--- UPDATE TRIGGERED (Assigning new data) ---")
      socket = assign(socket, assigns)

      # Log if data is ready but not pushed yet (waiting for chart-initialized)
      if !Enum.empty?(socket.assigns.chart_data) && !socket.assigns.data_pushed do
        # IO.puts("--- DATA READY, WAITING FOR CHART INITIALIZATION ---")
        # IO.inspect(socket.assigns.chart_id, label: "Chart ID")
        Logger.debug("Data ready, waiting for chart initialization: #{socket.assigns.chart_id}")
      end

      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    # Make sure assigns has default values for optional parameters
    assigns = assign_new(assigns, :start_time_limit, fn -> nil end)
    assigns = assign_new(assigns, :end_time_limit, fn -> nil end)
    assigns = assign_new(assigns, :chart_data, fn -> [] end)
    assigns = assign_new(assigns, :opts, fn -> %{} end)
    assigns = assign_new(assigns, :data_pushed, fn -> false end)

    ~H"""
    <div id={@chart_id} class="w-full bg-background chart-component-container">
      <div
        id={"#{@chart_id}-tradingview-chart"}
        phx-hook="TradingViewChart"
        phx-target={@myself}
        data-chart-id={@chart_id}
        data-chart-type={@chart_type}
        data-symbol={@symbol}
        data-timeframe={@timeframe}
        data-theme={@theme}
        data-start-time-limit={
          if @start_time_limit, do: DateTime.to_unix(@start_time_limit), else: nil
        }
        data-end-time-limit={if @end_time_limit, do: DateTime.to_unix(@end_time_limit), else: nil}
        data-opts={Jason.encode!(@opts)}
        class="w-full rounded-lg border border-border bg-card"
        style={"height: #{@height}; position: relative;"}
      >
        <.loading_overlay id={"#{@chart_id}-loader"} loading={@loading} />
        <p
          :if={!@loading}
          id={"#{@chart_id}-no-data-text"}
          class="absolute inset-0 flex items-center justify-center text-muted-foreground hidden"
        >
          No data available for display.
        </p>
      </div>
    </div>
    """
  end

  # Loading overlay component
  defp loading_overlay(assigns) do
    ~H"""
    <div
      :if={@loading}
      id={@id}
      class="absolute inset-0 flex items-center justify-center bg-background bg-opacity-75 z-10"
      aria-live="polite"
      aria-busy="true"
    >
      <div class="flex flex-col items-center">
        <.icon name="hero-arrow-path" class="h-6 w-6 animate-spin text-primary mb-2" />
        <span class="text-muted-foreground text-sm">Loading Chart Data...</span>
      </div>
    </div>
    """
  end
end
