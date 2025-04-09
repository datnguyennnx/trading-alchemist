defmodule CentralWeb.BacktestLive.Components.ChartControls do
  use Phoenix.Component

  alias CentralWeb.BacktestLive.Utils.DataFormatter

  import SaladUI.Button
  import SaladUI.DropdownMenu
  import SaladUI.Tooltip
  import SaladUI.Icon

  @doc """
  Renders the chart control panel with timeframe selector, symbol selector, and refresh button
  """
  attr :timeframe, :string, required: true, doc: "The current timeframe"
  attr :symbol, :string, required: true, doc: "The current symbol"
  attr :timeframes, :list, required: true, doc: "List of available timeframes"
  attr :symbols, :list, required: true, doc: "List of available symbols"

  def chart_controls(assigns) do
    ~H"""
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
            <div class="cursor-pointer select-none rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground" phx-click="set_timeframe" phx-value-timeframe={timeframe}><%= DataFormatter.timeframe_display(timeframe) %></div>
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
    """
  end
end
