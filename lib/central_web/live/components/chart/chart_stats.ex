defmodule CentralWeb.BacktestLive.Components.ChartStats do
  use Phoenix.Component

  attr :chart_data, :list, required: true

  def chart_stats(assigns) do
    ~H"""
    <div class="flex items-center gap-4">
      <div class="text-sm">
        <div class="text-muted-foreground">Open</div>
        <div class="font-medium">
          <%= if first = List.first(@chart_data) do %>
            {format_price(first.open)}
          <% end %>
        </div>
      </div>
      <div class="text-sm">
        <div class="text-muted-foreground">High</div>
        <div class="font-medium text-green-600">
          <%= if data = @chart_data do %>
            {format_price(Enum.max_by(data, & &1.high).high)}
          <% end %>
        </div>
      </div>
      <div class="text-sm">
        <div class="text-muted-foreground">Low</div>
        <div class="font-medium text-red-600">
          <%= if data = @chart_data do %>
            {format_price(Enum.min_by(data, & &1.low).low)}
          <% end %>
        </div>
      </div>
      <div class="text-sm">
        <div class="text-muted-foreground">Close</div>
        <div class="font-medium">
          <%= if last = List.last(@chart_data) do %>
            {format_price(last.close)}
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_price(price) when is_number(price) do
    "$#{:erlang.float_to_binary(price, decimals: 2)}"
  end

  defp format_price(_), do: "-"
end
