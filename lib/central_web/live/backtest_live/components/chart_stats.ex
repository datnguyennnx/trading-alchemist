defmodule CentralWeb.BacktestLive.Components.ChartStats do
  use Phoenix.Component

  alias CentralWeb.BacktestLive.Utils.DataFormatter

  import SaladUI.Separator

  @doc """
  Renders the chart statistics display with OHLC values
  """
  attr :chart_data, :list, required: true, doc: "The formatted chart data list"

  def chart_stats(assigns) do
    ~H"""
    <div class="flex items-center gap-3 flex-wrap">
      <div class="flex items-center gap-1">
        <span class="text-xs text-muted-foreground">Open</span>
        <span class="font-medium text-sm">
          {DataFormatter.format_price(DataFormatter.get_latest_price(@chart_data, :open))}
        </span>
      </div>
      <.separator orientation="vertical" class="h-5" />
      <div class="flex items-center gap-1">
        <span class="text-xs text-muted-foreground">High</span>
        <span class="font-medium text-sm text-green-500">
          {DataFormatter.format_price(DataFormatter.get_latest_price(@chart_data, :high))}
        </span>
      </div>
      <.separator orientation="vertical" class="h-5" />
      <div class="flex items-center gap-1">
        <span class="text-xs text-muted-foreground">Low</span>
        <span class="font-medium text-sm text-red-500">
          {DataFormatter.format_price(DataFormatter.get_latest_price(@chart_data, :low))}
        </span>
      </div>
      <.separator orientation="vertical" class="h-5" />
      <div class="flex items-center gap-1">
        <span class="text-xs text-muted-foreground">Close</span>
        <span class="font-medium text-sm">
          {DataFormatter.format_price(DataFormatter.get_latest_price(@chart_data, :close))}
        </span>
      </div>
    </div>
    """
  end
end
