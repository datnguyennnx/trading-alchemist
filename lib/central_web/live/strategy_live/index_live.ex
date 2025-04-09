defmodule CentralWeb.StrategyLive.IndexLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext

  import SaladUI.Card
  import SaladUI.Button

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:strategies, list_strategies())
     |> assign(:page_title, "Trading Strategies")}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Trading Strategies</h1>
        <.link navigate={~p"/strategies/new"}>
          <.button>Create Strategy</.button>
        </.link>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= if Enum.empty?(@strategies) do %>
          <div class="col-span-full">
            <.card>
              <.card_header>
                <.card_title>No Strategies Found</.card_title>
                <.card_description>Get started by creating your first trading strategy</.card_description>
              </.card_header>
              <.card_content>
                <p class="text-muted-foreground">
                  Define entry and exit rules, set risk parameters, and run backtests to evaluate performance.
                </p>
              </.card_content>
              <.card_footer>
                <.link navigate={~p"/strategies/new"}>
                  <.button class="w-full">Create Your First Strategy</.button>
                </.link>
              </.card_footer>
            </.card>
          </div>
        <% else %>
          <%= for strategy <- @strategies do %>
            <.card>
              <.card_header>
                <.card_title><%= strategy.name %></.card_title>
                <.card_description><%= truncate_description(strategy.description) %></.card_description>
              </.card_header>
              <.card_content>
                <div class="space-y-4">
                  <div class="flex justify-between">
                    <span class="text-muted-foreground">Symbol:</span>
                    <span class="font-medium"><%= strategy.config["symbol"] %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-muted-foreground">Timeframe:</span>
                    <span class="font-medium"><%= strategy.config["timeframe"] %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-muted-foreground">Rules:</span>
                    <span class="font-medium">
                      <%= "#{count_rules(strategy.config["entry_rules"])} entries, #{count_rules(strategy.config["exit_rules"])} exits" %>
                    </span>
                  </div>
                </div>
              </.card_content>
              <.card_footer class="flex justify-between">
                <.link navigate={~p"/strategies/#{strategy.id}"}>
                  <.button variant="outline">View</.button>
                </.link>
                <.link navigate={~p"/backtest/#{strategy.id}"}>
                  <.button>Run Backtest</.button>
                </.link>
              </.card_footer>
            </.card>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp list_strategies do
    StrategyContext.list_strategies()
  end

  defp truncate_description(nil), do: "No description provided"
  defp truncate_description(description) do
    if String.length(description) > 100 do
      String.slice(description, 0..97) <> "..."
    else
      description
    end
  end

  defp count_rules(nil), do: 0
  defp count_rules(rules) when is_list(rules), do: length(rules)
  defp count_rules(rules) when is_map(rules), do: 1
  defp count_rules(_), do: 0
end
