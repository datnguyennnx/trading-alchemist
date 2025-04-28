defmodule CentralWeb.StrategyLive.Components.BacktestHistory do
  use CentralWeb, :live_component

  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.Table
  import CentralWeb.Components.UI.Badge
  alias CentralWeb.BacktestLive.Utils.FormatterUtils

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.card>
        <.card_header class="flex flex-row items-start justify-between">
          <.card_title>Backtest History</.card_title>
          <div class="px-2 py-0.5 rounded-full bg-muted text-sm font-bold">
            <%= length(@backtests) %> backtests runs
          </div>
        </.card_header>
        <.card_content>
          <%= if Enum.empty?(@backtests) do %>
            <div class="text-center text-muted-foreground italic">
              No backtests found
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <.table>
                <.table_header>
                  <.table_row>
                    <.table_head>Date & Time</.table_head>
                    <.table_head class="text-center">Status</.table_head>
                    <.table_head>Symbol</.table_head>
                    <.table_head>Timeframe</.table_head>
                    <.table_head numeric>Initial</.table_head>
                    <.table_head numeric>Final</.table_head>
                    <.table_head numeric>PnL</.table_head>
                    <.table_head numeric>PnL %</.table_head>
                    <.table_head class="text-right">Actions</.table_head>
                  </.table_row>
                </.table_header>
                <.table_body>
                  <%= for backtest <- Enum.sort_by(@backtests, & &1.inserted_at, :desc) do %>
                    <.table_row>
                      <.table_cell>
                        <%= FormatterUtils.format_datetime(backtest.inserted_at) %>
                      </.table_cell>
                      <.table_cell class="text-center">
                        <.badge variant={status_badge_variant(backtest.status)} class="whitespace-nowrap">
                          <%= String.upcase(to_string(backtest.status)) %>
                        </.badge>
                      </.table_cell>
                      <.table_cell><%= backtest.symbol %></.table_cell>
                      <.table_cell><%= backtest.timeframe %></.table_cell>
                      <.table_cell numeric><%= FormatterUtils.format_currency(backtest.initial_balance) %></.table_cell>
                      <.table_cell numeric><%= FormatterUtils.format_currency(backtest.final_balance) %></.table_cell>
                      <.table_cell numeric>
                        <p class={pnl_color(Map.get(backtest, :total_pnl))}>
                          <%= FormatterUtils.format_currency(Map.get(backtest, :total_pnl)) %>
                        </p>
                      </.table_cell>
                      <.table_cell numeric>
                        <p class={pnl_color(Map.get(backtest, :total_pnl_percentage))}>
                          <%= FormatterUtils.format_percent(Map.get(backtest, :total_pnl_percentage)) %>
                        </p>
                      </.table_cell>
                      <.table_cell class="text-right">
                        <.link navigate={~p"/backtest/#{backtest.id}"} class=" text-primary hover:underline whitespace-nowrap">
                          View Details
                        </.link>
                      </.table_cell>
                    </.table_row>
                  <% end %>
                </.table_body>
              </.table>
            </div>
          <% end %>
        </.card_content>
      </.card>
    </div>
    """
  end

  # Helper functions
  defp status_badge_variant(:completed), do: "success"
  defp status_badge_variant(:running), do: "info"
  defp status_badge_variant(:pending), do: "warning"
  defp status_badge_variant(:failed), do: "destructive"
  defp status_badge_variant(:cancelled), do: "secondary"
  defp status_badge_variant(_), do: "outline"

  defp pnl_color(nil), do: "text-muted-foreground"
  defp pnl_color(%Decimal{} = value), do: FormatterUtils.color_class(value)
  defp pnl_color(value) when is_number(value), do: FormatterUtils.color_class(value)
  defp pnl_color(_), do: "text-muted-foreground"
end
