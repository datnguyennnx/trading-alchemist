defmodule CentralWeb.BacktestLive.IndexLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext
  alias Central.Backtest.Contexts.BacktestContext

  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.Button

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:strategies, list_strategies())
     |> assign(:recent_backtests, list_recent_backtests())
     |> assign(:page_title, "Backtest Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold mb-6">Backtest Dashboard</h1>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2">
          <.card>
            <.card_header>
              <.card_title>Your Strategies</.card_title>
              <.card_description>Select a strategy to run a backtest</.card_description>
            </.card_header>
            <.card_content>
              <%= if Enum.empty?(@strategies) do %>
                <div class="text-center py-8">
                  <h3 class="text-lg font-medium mb-2">No Strategies Found</h3>
                  <p class="text-muted-foreground mb-4">Create a strategy before running backtests</p>
                  <.link navigate={~p"/strategies/new"}>
                    <.button>Create Your First Strategy</.button>
                  </.link>
                </div>
              <% else %>
                <div class="space-y-4">
                  <%= for strategy <- @strategies do %>
                    <div
                      class="border rounded-lg p-4 hover:border-primary hover:bg-accent cursor-pointer transition-colors"
                      phx-click="select_strategy"
                      phx-value-id={strategy.id}
                    >
                      <div class="flex justify-between items-center">
                        <div>
                          <h3 class="font-medium text-lg">{strategy.name}</h3>
                          <p class="text-muted-foreground text-sm">
                            {truncate_description(strategy.description)}
                          </p>
                        </div>
                        <div class="flex space-x-2 items-center">
                          <div class="text-right text-sm">
                            <div>{strategy.config["symbol"]}</div>
                            <div class="text-muted-foreground">{strategy.config["timeframe"]}</div>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </.card_content>
            <.card_footer>
              <.link
                navigate={~p"/strategies"}
                class="text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                View all strategies →
              </.link>
            </.card_footer>
          </.card>
        </div>

        <div>
          <.card>
            <.card_header>
              <.card_title>Recent Backtests</.card_title>
              <.card_description>Your most recent backtest results</.card_description>
            </.card_header>
            <.card_content>
              <%= if Enum.empty?(@recent_backtests) do %>
                <div class="py-4">
                  <p class="text-muted-foreground text-center">No backtests found</p>
                </div>
              <% else %>
                <div class="space-y-3">
                  <%= for backtest <- @recent_backtests do %>
                    <div class="border rounded-lg p-3">
                      <div class="flex justify-between mb-2">
                        <div class="font-medium">{backtest.strategy.name}</div>
                        <div class={status_class(backtest.status)}>
                          {String.capitalize(to_string(backtest.status))}
                        </div>
                      </div>
                      <div class="text-sm text-muted-foreground mb-2 flex justify-between">
                        <div>{backtest.symbol} ({backtest.timeframe})</div>
                        <div>{format_date(backtest.inserted_at)}</div>
                      </div>
                      <div class="flex justify-between text-sm">
                        <div>
                          Initial: {format_balance(backtest.initial_balance)}
                        </div>
                        <div>
                          <%= if backtest.status == :completed do %>
                            Final: {format_balance(backtest.final_balance)}
                          <% else %>
                            Trades: {length(backtest.trades || [])}
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </.card_content>
          </.card>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("select_strategy", %{"id" => strategy_id}, socket) do
    {:noreply, redirect(socket, to: ~p"/backtest/#{strategy_id}")}
  end

  defp list_strategies do
    StrategyContext.list_strategies()
  end

  defp list_recent_backtests do
    BacktestContext.list_recent_backtests(5)
  end

  defp truncate_description(nil), do: "No description provided"

  defp truncate_description(description) do
    if String.length(description) > 100 do
      String.slice(description, 0..97) <> "..."
    else
      description
    end
  end

  defp status_class(:pending), do: "text-yellow-600"
  defp status_class(:running), do: "text-blue-600"
  defp status_class(:completed), do: "text-green-600"
  defp status_class(:failed), do: "text-red-600"
  defp status_class(_), do: "text-gray-600"

  defp format_balance(balance) when is_number(balance) do
    :erlang.float_to_binary(balance, decimals: 2)
  end

  defp format_balance(balance), do: balance

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end
end
