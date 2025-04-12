defmodule CentralWeb.StrategyLive.ShowLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext
  alias CentralWeb.Components.UI.Icon

  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.Button

  # Import the icon component
  import Icon, only: [icon: 1]

  def mount(%{"id" => id}, _session, socket) do
    strategy = StrategyContext.get_strategy!(id)

    {:ok,
     socket
     |> assign(:strategy, strategy)
     |> assign(:page_title, strategy.name)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold">{@strategy.name}</h1>
          <p class="text-muted-foreground mt-1">{@strategy.description}</p>
        </div>
        <div class="flex space-x-3">
          <.link navigate={~p"/strategies/#{@strategy.id}/edit"}>
            <.button variant="outline">Edit Strategy</.button>
          </.link>
          <.link navigate={~p"/backtest/#{@strategy.id}"}>
            <.button>Run Backtest</.button>
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <.card class="lg:col-span-2">
          <.card_header>
            <.card_title>Strategy Configuration</.card_title>
            <.card_description>Parameters and settings for the trading strategy</.card_description>
          </.card_header>
          <.card_content>
            <div class="space-y-6">
              <div>
                <h3 class="text-lg font-medium mb-2">Trading Parameters</h3>
                <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <div class="border rounded-lg p-3">
                    <p class="text-muted-foreground text-sm">Symbol</p>
                    <p class="font-semibold text-lg">{@strategy.config["symbol"]}</p>
                  </div>
                  <div class="border rounded-lg p-3">
                    <p class="text-muted-foreground text-sm">Timeframe</p>
                    <p class="font-semibold text-lg">{@strategy.config["timeframe"]}</p>
                  </div>
                  <div class="border rounded-lg p-3">
                    <p class="text-muted-foreground text-sm">Risk per Trade</p>
                    <p class="font-semibold text-lg">{@strategy.config["risk_per_trade"]}%</p>
                  </div>
                </div>
              </div>

              <div>
                <h3 class="text-lg font-medium mb-2">Entry Rules</h3>
                <div class="space-y-3">
                  <%= if Enum.empty?(@strategy.config["entry_rules"] || []) do %>
                    <p class="text-muted-foreground italic">No entry rules defined</p>
                  <% else %>
                    <%= for rule <- @strategy.config["entry_rules"] do %>
                      <div class="border rounded-lg p-3">
                        <div class="flex justify-between items-center">
                          <p class="font-medium text-md">{format_rule_name(rule["strategy"])}</p>
                          <div class="flex space-x-2">
                            <span class="bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 rounded-md px-2 py-1 text-xs">
                              Period: {rule["period"]}
                            </span>
                            <span class="bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 rounded-md px-2 py-1 text-xs">
                              Value: {rule["value"]}
                            </span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>

              <div>
                <h3 class="text-lg font-medium mb-2">Exit Rules</h3>
                <div class="space-y-3">
                  <%= if Enum.empty?(@strategy.config["exit_rules"] || []) do %>
                    <p class="text-muted-foreground italic">No exit rules defined</p>
                  <% else %>
                    <%= for rule <- @strategy.config["exit_rules"] do %>
                      <div class="border rounded-lg p-3">
                        <div class="flex justify-between items-center">
                          <p class="font-medium text-md">{format_rule_name(rule["strategy"])}</p>
                          <div class="flex space-x-2 flex-wrap">
                            <span class="bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300 rounded-md px-2 py-1 text-xs whitespace-nowrap">
                              SL: {rule["stop_loss"]}%
                            </span>
                            <span class="bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 rounded-md px-2 py-1 text-xs whitespace-nowrap">
                              TP: {rule["take_profit"]}%
                            </span>
                            <span class="bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 rounded-md px-2 py-1 text-xs">
                              Period: {rule["period"]}
                            </span>
                            <span class="bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 rounded-md px-2 py-1 text-xs">
                              Value: {rule["value"]}
                            </span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          </.card_content>
        </.card>

        <div class="space-y-6">
          <.card>
            <.card_header>
              <.card_title>Strategy Statistics</.card_title>
              <.card_description>Performance metrics from previous backtests</.card_description>
            </.card_header>
            <.card_content>
              <div class="space-y-4">
                <div class="flex justify-between">
                  <span class="text-muted-foreground">Total Backtests:</span>
                  <span class="font-medium">0</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-muted-foreground">Best Performance:</span>
                  <span class="font-medium">-</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-muted-foreground">Average Profit:</span>
                  <span class="font-medium">-</span>
                </div>
              </div>
            </.card_content>
            <.card_footer>
              <.link navigate={~p"/backtest/#{@strategy.id}"} class="w-full">
                <.button class="w-full">Run New Backtest</.button>
              </.link>
            </.card_footer>
          </.card>

          <.card>
            <.card_header>
              <.card_title>Quick Actions</.card_title>
            </.card_header>
            <.card_content>
              <div class="space-y-3">
                <.link navigate={~p"/strategies/#{@strategy.id}/edit"} class="w-full block">
                  <.button variant="outline" class="w-full justify-start">
                    <.icon name="hero-pencil-solid" class="h-4 w-4 mr-2" />
                    Edit Strategy
                  </.button>
                </.link>
                <.link navigate={~p"/backtest/#{@strategy.id}"} class="w-full block">
                  <.button variant="outline" class="w-full justify-start">
                    <.icon name="hero-play-circle-solid" class="h-4 w-4 mr-2" />
                    Run Backtest
                  </.button>
                </.link>
                <button type="button" phx-click="delete_strategy" class="w-full">
                  <.button variant="outline" class="w-full justify-start">
                    <.icon name="hero-trash-solid" class="h-4 w-4 mr-2" />
                    Delete Strategy
                  </.button>
                </button>
              </div>
            </.card_content>
          </.card>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("delete_strategy", _, socket) do
    {:ok, _} = StrategyContext.delete_strategy(socket.assigns.strategy)

    {:noreply,
     socket
     |> put_flash(:info, "Strategy deleted successfully")
     |> redirect(to: ~p"/strategies")}
  end

  defp format_rule_name("above_sma"), do: "Price Above SMA"
  defp format_rule_name("below_sma"), do: "Price Below SMA"
  defp format_rule_name("rsi_oversold"), do: "RSI Oversold"
  defp format_rule_name("rsi_overbought"), do: "RSI Overbought"
  defp format_rule_name(name) when is_binary(name), do: name
  defp format_rule_name(_), do: "Unknown Rule"
end
