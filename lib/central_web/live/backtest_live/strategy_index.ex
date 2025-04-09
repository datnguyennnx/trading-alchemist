defmodule CentralWeb.BacktestLive.StrategyIndex do
  use CentralWeb, :live_view

  import SaladUI.Card
  import SaladUI.Button

  alias Central.Backtest.Contexts.StrategyContext

  @impl true
  def mount(_params, _session, socket) do
    strategies = StrategyContext.list_strategies()

    {:ok,
     assign(socket,
       page_title: "Trading Strategies",
       strategies: strategies
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold text-slate-900">Trading Strategies</h1>
        <.link
          navigate={~p"/strategies/new"}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          Create New Strategy
        </.link>
      </div>

      <%= if Enum.empty?(@strategies) do %>
        <.card>
          <.card_content>
            <div class="flex flex-col items-center justify-center py-12">
              <p class="text-slate-600 mb-4">No strategies found.</p>
              <.link navigate={~p"/strategies/new"} class="text-indigo-600 hover:text-indigo-500">
                Create your first strategy
              </.link>
            </div>
          </.card_content>
        </.card>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
          <%= for strategy <- @strategies do %>
            <.card>
              <.card_header>
                <.card_title>
                  {strategy.name}
                </.card_title>
                <.card_description>
                  {if strategy.description && strategy.description != "",
                    do: strategy.description,
                    else: "No description"}
                </.card_description>
              </.card_header>
              <.card_content>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <p class="text-sm font-medium text-slate-500">Symbol</p>
                    <p class="mt-1 text-sm text-slate-900">{strategy.config["symbol"]}</p>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-slate-500">Timeframe</p>
                    <p class="mt-1 text-sm text-slate-900">{strategy.config["timeframe"]}</p>
                  </div>
                </div>

                <div class="mt-4">
                  <p class="text-sm font-medium text-slate-500">Rules</p>
                  <div class="mt-2 space-y-2">
                    <div class="p-2 bg-slate-50 rounded-md">
                      <p class="text-xs font-medium text-slate-700">Entry</p>
                      <p class="text-sm text-slate-900">
                        {summarize_rules(strategy.config["entry_rules"])}
                      </p>
                    </div>
                    <div class="p-2 bg-slate-50 rounded-md">
                      <p class="text-xs font-medium text-slate-700">Exit</p>
                      <p class="text-sm text-slate-900">
                        {summarize_rules(strategy.config["exit_rules"])}
                      </p>
                    </div>
                  </div>
                </div>

                <div class="mt-4">
                  <p class="text-sm font-medium text-slate-500">Backtests</p>
                  <p class="mt-1 text-sm text-slate-900">
                    {length(strategy.backtests || [])} backtest(s) performed
                  </p>
                </div>
              </.card_content>
              <.card_footer>
                <div class="flex justify-between w-full">
                  <.button
                    phx-click="delete_strategy"
                    phx-value-id={strategy.id}
                    variant="ghost"
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </.button>
                  <.link
                    navigate={~p"/backtest/#{strategy.id}"}
                    class="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Run Backtest
                  </.link>
                </div>
              </.card_footer>
            </.card>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("delete_strategy", %{"id" => id}, socket) do
    strategy = StrategyContext.get_strategy!(id)
    {:ok, _} = StrategyContext.delete_strategy(strategy)

    {:noreply,
     socket
     |> put_flash(:info, "Strategy deleted successfully")
     |> assign(strategies: StrategyContext.list_strategies())}
  end

  defp summarize_rules(rules) when is_list(rules) and length(rules) > 0 do
    rules
    |> Enum.map(fn rule ->
      "#{rule["indicator"]} #{rule["condition"]} #{rule["value"]}"
    end)
    |> Enum.join(" AND ")
  end

  defp summarize_rules(_), do: "No rules configured"
end
