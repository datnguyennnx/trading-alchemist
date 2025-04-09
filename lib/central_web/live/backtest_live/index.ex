defmodule CentralWeb.BacktestLive.Index do
  use CentralWeb, :live_view

  import SaladUI.Card

  alias Central.Backtest.Contexts.BacktestContext

  @impl true
  def mount(_params, _session, socket) do
    backtests = BacktestContext.list_recent_backtests(10)

    {:ok,
     assign(socket,
       page_title: "Recent Backtests",
       backtests: backtests
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold text-slate-900">Recent Backtests</h1>
        <.link
          navigate={~p"/strategies/new"}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          Create New Strategy
        </.link>
      </div>

      <%= if Enum.empty?(@backtests) do %>
        <.card>
          <.card_content>
            <div class="flex flex-col items-center justify-center py-12">
              <p class="text-slate-600 mb-4">No backtests found.</p>
              <.link navigate={~p"/strategies"} class="text-indigo-600 hover:text-indigo-500">
                View Strategies
              </.link>
            </div>
          </.card_content>
        </.card>
      <% else %>
        <div class="grid grid-cols-1 gap-4 mb-8">
          <%= for backtest <- @backtests do %>
            <.card>
              <.card_header>
                <.card_title>
                  {backtest.strategy.name}
                </.card_title>
                <.card_description>
                  Started at {Calendar.strftime(backtest.start_time, "%Y-%m-%d %H:%M")}
                </.card_description>
              </.card_header>
              <.card_content>
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div>
                    <p class="text-sm font-medium text-slate-500">Initial Balance</p>
                    <p class="mt-1 text-lg font-semibold text-slate-900">
                      ${backtest.initial_balance}
                    </p>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-slate-500">Status</p>
                    <div class="mt-1">
                      <span class={status_badge_class(backtest.status)}>
                        {String.capitalize(backtest.status)}
                      </span>
                    </div>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-slate-500">Final Balance</p>
                    <p class="mt-1 text-lg font-semibold text-slate-900">
                      <%= if backtest.final_balance do %>
                        ${backtest.final_balance}
                      <% else %>
                        -
                      <% end %>
                    </p>
                  </div>
                </div>
              </.card_content>
              <.card_footer>
                <.link
                  navigate={~p"/backtest/#{backtest.id}"}
                  class="text-indigo-600 hover:text-indigo-500 text-sm font-medium"
                >
                  View Details
                </.link>
              </.card_footer>
            </.card>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_badge_class(status) do
    base = "px-2 py-1 text-xs font-medium rounded-full"

    case status do
      "completed" -> "#{base} bg-green-100 text-green-800"
      "running" -> "#{base} bg-blue-100 text-blue-800"
      "failed" -> "#{base} bg-red-100 text-red-800"
      "pending" -> "#{base} bg-yellow-100 text-yellow-800"
      _ -> "#{base} bg-gray-100 text-gray-800"
    end
  end
end
