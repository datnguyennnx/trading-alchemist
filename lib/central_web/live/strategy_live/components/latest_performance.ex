defmodule CentralWeb.StrategyLive.Components.LatestPerformance do
  use CentralWeb, :live_component
  import CentralWeb.Components.UI.Card
  alias CentralWeb.BacktestLive.Utils.FormatterUtils
  alias Decimal

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.card>
        <.card_header class="flex items-start">
          <.card_title>Latest Performance</.card_title>
        </.card_header>
        <.card_content class="space-y-4">
          <div class="grid grid-cols-3 gap-4">
            <div>
              <p class="text-muted-foreground mb-1">Initial</p>
              <p class="text-md font-medium"><%= FormatterUtils.format_currency(@backtest.initial_balance) %></p>
            </div>
            <div>
              <p class="text-muted-foreground mb-1">Final</p>
              <p class="text-md font-medium"><%= FormatterUtils.format_currency(@backtest.final_balance) %></p>
            </div>
            <div>
              <%
                total_pnl = calculate_total_pnl(@backtest)
                total_pnl_percentage = calculate_pnl_percentage(@backtest.initial_balance, @backtest.final_balance)
                pnl_color = if Decimal.compare(total_pnl, Decimal.new(0)) == :gt, do: "text-green-600", else: "text-red-600"
              %>
              <p class="text-muted-foreground mb-1">Profit/Loss</p>
              <p class={"text-md font-medium #{pnl_color}"}>
                <%= FormatterUtils.format_currency(total_pnl) %>
                (<%= FormatterUtils.format_percent(total_pnl_percentage) %>)
              </p>
            </div>
          </div>
        </.card_content>
      </.card>
    </div>
    """
  end
  # Calculate total PnL from final and initial balance
  defp calculate_total_pnl(backtest) do
    if is_nil(backtest.final_balance) || is_nil(backtest.initial_balance) do
      Decimal.new(0)
    else
      Decimal.sub(backtest.final_balance, backtest.initial_balance)
    end
  end

  # Calculate PnL percentage
  defp calculate_pnl_percentage(initial_balance, final_balance) do
    if is_nil(initial_balance) || is_nil(final_balance) || Decimal.compare(initial_balance, Decimal.new(0)) == :eq do
      Decimal.new(0)
    else
      pnl = Decimal.sub(final_balance, initial_balance)
      Decimal.div(pnl, initial_balance)
    end
  end
end
