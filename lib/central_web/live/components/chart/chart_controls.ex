defmodule CentralWeb.BacktestLive.Components.ChartControls do
  use Phoenix.Component
  import CentralWeb.Components.UI.Button

  attr :id, :string, default: "chart-controls"
  attr :timeframe, :string, required: true
  attr :symbol, :string, required: true
  attr :timeframes, :list, default: []
  attr :symbols, :list, default: []
  attr :myself, :any, required: true

  def chart_controls(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-3">
      <div class="flex items-center gap-2">
        <div class="flex rounded-md shadow-sm">
          <%= for tf <- @timeframes do %>
            <button
              type="button"
              phx-click="set_timeframe"
              phx-value-timeframe={tf}
              phx-target={@myself}
              class={
                [
                  "relative inline-flex items-center px-3 py-2 text-sm font-medium focus:z-10",
                  if tf == @timeframe do
                    "bg-primary text-primary-foreground hover:bg-primary/90"
                  else
                    "bg-background text-foreground hover:bg-accent"
                  end,
                  # First button
                  if(tf == List.first(@timeframes), do: "rounded-l-md"),
                  # Last button
                  if(tf == List.last(@timeframes), do: "rounded-r-md"),
                  # Middle buttons
                  if(tf not in [List.first(@timeframes), List.last(@timeframes)],
                    do: "border-l border-r border-border"
                  )
                ]
              }
            >
              {tf}
            </button>
          <% end %>
        </div>
      </div>

      <%= if length(@symbols) > 1 do %>
        <div class="flex items-center gap-2">
          <select
            phx-change="set_symbol"
            phx-target={@myself}
            class="h-10 w-[180px] rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background"
          >
            <%= for symbol <- @symbols do %>
              <option value={symbol} selected={symbol == @symbol}>
                {symbol}
              </option>
            <% end %>
          </select>
        </div>
      <% end %>

      <.button variant="outline" phx-click="refresh_data" phx-target={@myself} class="ml-auto">
        Refresh
      </.button>
    </div>
    """
  end
end
