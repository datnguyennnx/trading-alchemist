defmodule CentralWeb.StrategyLive.Components.BacktestHistory do
  use CentralWeb, :live_component

  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.DataTable
  import CentralWeb.Components.UI.Badge
  alias CentralWeb.BacktestLive.Utils.FormatterUtils

  # Note: The parent LiveView now passes: rows, page, page_size, total_entries, on_page_change
  # We don't need to explicitly declare them with `attr` because live_component passes assigns implicitly.

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.card>
        <.card_header class="flex flex-row items-start justify-between">
          <.card_title>Backtest History</.card_title>
          <div class="px-2 py-0.5 rounded-full bg-muted text-sm font-bold">
            {@total_entries} backtests runs
          </div>
        </.card_header>
        <.card_content>
          <.data_table
            id={"#{@id}-table"}
            rows={@backtest_data}
            row_id={fn bt -> bt.id end}
            page={@current_page}
            page_size={@page_size}
            total_entries={@total_entries}
            on_page_change={@on_page_change}
          >
            <:col :let={bt} label="Date & Time">
              <%= FormatterUtils.format_datetime(bt.inserted_at) %>
            </:col>
            <:col :let={bt} label="Status" header_class="text-center">
              <div class="flex justify-center">
                <.badge
                  color={status_badge_props(bt.status).color}
                  class="whitespace-nowrap"
                >
                  <%= String.upcase(to_string(bt.status)) %>
                </.badge>
              </div>
            </:col>
            <:col :let={bt} label="Symbol">
              <%= bt.symbol %>
            </:col>
            <:col :let={bt} label="Timeframe">
              <%= bt.timeframe %>
            </:col>
            <:col :let={bt} label="Initial" numeric>
              <%= FormatterUtils.format_currency(bt.initial_balance) %>
            </:col>
            <:col :let={bt} label="Final" numeric>
              <%= FormatterUtils.format_currency(bt.final_balance) %>
            </:col>
            <:col :let={bt} label="PnL" numeric>
              <p class={pnl_color(Map.get(bt, :total_pnl))}>
                <%= FormatterUtils.format_currency(Map.get(bt, :total_pnl)) %>
              </p>
            </:col>
            <:col :let={bt} label="PnL %" numeric>
              <p class={pnl_color(Map.get(bt, :total_pnl_percentage))}>
                <%= FormatterUtils.format_percent(Map.get(bt, :total_pnl_percentage)) %>
              </p>
            </:col>

            <:actions :let={bt}>
              <div class="text-right">
                <.link
                  navigate={~p"/backtest/#{bt.id}"}
                  class="text-primary hover:underline whitespace-nowrap"
                >
                  View Details
                </.link>
              </div>
            </:actions>

            <:empty_state>
              <div class="text-center text-muted-foreground italic p-8">
                No backtests found
              </div>
            </:empty_state>
          </.data_table>
        </.card_content>
      </.card>
    </div>
    """
  end

  # Helper functions
  defp status_badge_props(:completed), do: %{color: "green", icon: "hero-check-circle"}
  defp status_badge_props(:running), do: %{color: "sky", icon: "hero-arrow-path"}
  defp status_badge_props(:pending), do: %{color: "amber", icon: "hero-clock"}
  defp status_badge_props(:failed), do: %{color: "red", icon: "hero-x-circle"}
  defp status_badge_props(:cancelled), do: %{color: "gray", icon: "hero-no-symbol"}
  defp status_badge_props(_), do: %{color: "gray", icon: nil}

  defp pnl_color(nil), do: "text-muted-foreground"
  defp pnl_color(%Decimal{} = value), do: FormatterUtils.color_class(value)
  defp pnl_color(value) when is_number(value), do: FormatterUtils.color_class(value)
  defp pnl_color(_), do: "text-muted-foreground"
end
