defmodule CentralWeb.BacktestLive.ShowLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.BacktestContext
  alias Central.Backtest.Contexts.TradeContext
  require Logger

  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.DataTable

  alias CentralWeb.BacktestLive.Utils.FormatterUtils
  alias CentralWeb.Live.Components.Chart.BacktestChartComponent

  @trades_page_size 50

  @impl true
  def mount(%{"id" => backtest_id_str}, session, socket) do
    try do
      backtest = BacktestContext.get_backtest!(backtest_id_str)
      trades_page = TradeContext.list_trades_for_backtest_paginated(backtest.id, 1, @trades_page_size)
      all_trades_for_chart = TradeContext.list_trades_for_backtest(backtest.id)

      # Get the total number of trades
      total_trades = length(all_trades_for_chart)

      backtest_with_trades_page = Map.put(backtest, :trades, trades_page)

      # Calculate total PnL and PnL percentage
      total_pnl = calculate_total_pnl(backtest)
      total_pnl_percentage = calculate_pnl_percentage(backtest.initial_balance, backtest.final_balance)

      # Get strategy config with safety check
      strategy_config =
        case backtest.strategy do
          %{config: config} when is_map(config) -> config
          _ -> %{}
        end

      socket =
        socket
        |> assign(:page_title, "Backtest: #{FormatterUtils.format_datetime(backtest.inserted_at)}")
        |> assign(:strategy, backtest.strategy)
        |> assign(:backtest, backtest_with_trades_page)
        |> assign(:all_trades_for_chart, all_trades_for_chart)
        |> assign(:backtest_config, strategy_config)
        |> assign(:total_pnl, total_pnl)
        |> assign(:total_pnl_percentage, total_pnl_percentage)
        |> assign(:total_trades, total_trades)
        |> assign(:trade_page, 1)
        |> assign(:trade_page_size, @trades_page_size)
        |> assign(:current_page, :backtest_show)
        |> assign_new(:chart_theme, fn -> session["theme"] || "light" end)

      {:ok, socket}
    rescue
      Ecto.NoResultsError ->
        {:ok,
         socket
         |> put_flash(:error, "Backtest not found.")
         |> redirect(to: ~p"/strategies")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <%= if @backtest do %>
        <%!-- Header Section --%>
        <div class="mb-6 border-b pb-4">
          <div class="flex flex-col md:flex-row md:items-center md:justify-between mb-2">
            <div>
              <p class="text-sm text-muted-foreground">
                Strategy: <.link navigate={~p"/strategies/#{@strategy.id}"} class="hover:underline"><%= @strategy.name %></.link>
              </p>
              <h1 class="text-2xl font-bold">
                Backtest: <%= FormatterUtils.format_datetime(@backtest.inserted_at) %>
              </h1>
              <p class="text-sm text-muted-foreground">
                <%= @backtest.symbol %> / <%= @backtest.timeframe %> | <%= format_time_range(@backtest.start_time, @backtest.end_time) %>
              </p>
            </div>
            <div class="mt-3 md:mt-0">
              <.link navigate={~p"/strategies/#{@strategy.id}"}>
                 <.button variant="outline">Back to Strategy</.button>
              </.link>
            </div>
          </div>

          <%!-- Key Stats Row --%>
          <div class="flex flex-wrap gap-4 text-sm mt-3">
            <div class="flex items-center space-x-2">
              <p class="text-muted-foreground">Final Balance:</p>
              <p class="font-semibold"><%= FormatterUtils.format_currency(@backtest.final_balance) %></p>
            </div>
            <div class="flex items-center space-x-2">
              <p class="text-muted-foreground">Total PnL:</p>
              <p class={Enum.join(["font-semibold", pnl_color(@total_pnl)], " ")}>
                <%= FormatterUtils.format_currency(@total_pnl) %>
              </p>
            </div>
            <div class="flex items-center space-x-2">
              <p class="text-muted-foreground">PnL %:</p>
              <p class={Enum.join(["font-semibold", pnl_color(@total_pnl_percentage)], " ")}>
                 <%= FormatterUtils.format_percent(@total_pnl_percentage) %>
               </p>
            </div>
            <div class="flex items-center space-x-2">
              <p class="text-muted-foreground">Total Trades:</p>
              <p class="font-semibold"><%= @total_trades || "N/A" %></p>
            </div>
          </div>
        </div>

        <%!-- Main Content Grid --%>
        <div class="grid grid-cols-1 lg:grid-cols-6 gap-6">
          <%!-- Left Column: Chart & Trades Table --%>
          <div class="lg:col-span-4 space-y-6">
            <%!-- Chart --%>
            <.card>
              <.card_header>
                <.card_title>Market Chart</.card_title>
              </.card_header>
              <.card_content>
                <.live_component
                  module={BacktestChartComponent}
                  id={"backtest-chart-#{@backtest.id}"}
                  backtest={@backtest}
                  theme={@chart_theme}
                  height="500px"
                  show_trades={true}
                  trades={@all_trades_for_chart}
                />
              </.card_content>
            </.card>

            <%!-- Trades Table --%>
            <.card>
               <.card_header>
                 <.card_title>Trades</.card_title>
                 <.card_description>Detailed list of trades executed during the backtest.</.card_description>
               </.card_header>
               <.card_content>
                <.data_table
                  id={"trades-table-#{@backtest.id}"}
                  rows={@backtest.trades}
                  row_id={fn trade -> trade.id end}
                  page={@trade_page}
                  page_size={@trade_page_size}
                  total_entries={@total_trades || 0}
                  on_page_change="trade_page_changed"
                  phx_value_keys={%{backtest_id: @backtest.id}}
                  row_numbers={true}
                  compact={true}
                >
                  <:col :let={trade} field={:entry_time} label="Entry Time">
                    <%= FormatterUtils.format_datetime(trade.entry_time) %>
                  </:col>
                  <:col :let={trade} field={:side} label="Side">
                    <p class={side_color(trade.side)}><%= String.upcase(to_string(trade.side)) %></p>
                  </:col>
                  <:col :let={trade} field={:entry_price} label="Entry Price" numeric>
                    <%= trade.entry_price %>
                  </:col>
                  <:col :let={trade} field={:exit_price} label="Exit Price" numeric>
                    <%= trade.exit_price %>
                  </:col>
                  <:col :let={trade} field={:pnl} label="PnL" numeric pnl>
                    <p class={pnl_color(trade.pnl)}><%= FormatterUtils.format_currency(trade.pnl) %></p>
                  </:col>
                  <:col :let={trade} field={:pnl_percentage} label="PnL %" numeric pnl>
                    <p class={pnl_color(trade.pnl_percentage)}>
                      <%= FormatterUtils.format_percent(trade.pnl_percentage) %>
                    </p>
                  </:col>
                </.data_table>
              </.card_content>
            </.card>
          </div>

          <%!-- Right Column: Backtest Info --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Backtest Details --%>
            <.card>
              <.card_header>
                <.card_title>Backtest Details</.card_title>
              </.card_header>
              <.card_content>
                <div class="space-y-4 text-sm">
                  <div>
                    <p class="text-muted-foreground">Status</p>
                    <p class="font-medium mt-1">
                      <p class={status_color(@backtest.status)}>
                        <%= String.upcase(to_string(@backtest.status)) %>
                      </p>
                    </p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Symbol</p>
                    <p class="font-medium mt-1"><%= @backtest.symbol %></p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Timeframe</p>
                    <p class="font-medium mt-1"><%= @backtest.timeframe %></p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Date Range</p>
                    <p class="font-medium mt-1"><%= format_time_range(@backtest.start_time, @backtest.end_time) %></p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Initial Balance</p>
                    <p class="font-medium mt-1"><%= FormatterUtils.format_currency(@backtest.initial_balance) %></p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Position Size</p>
                    <p class="font-medium mt-1"><%= get_in(@backtest.metadata, ["position_size"]) || "N/A" %>%</p>
                  </div>
                </div>
              </.card_content>
            </.card>

            <%!-- Performance Summary --%>
            <.card>
              <.card_header>
                <.card_title>Performance Summary</.card_title>
              </.card_header>
              <.card_content>
                <div class="space-y-4 text-sm">
                  <div>
                    <p class="text-muted-foreground">Total Trades</p>
                    <p class="font-medium mt-1"><%= @total_trades || 0 %></p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Win Rate</p>
                    <p class="font-medium mt-1"><%= calculate_win_rate(@all_trades_for_chart) %>%</p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Average Profit</p>
                    <p class="font-medium mt-1"><%= calculate_avg_profit(@all_trades_for_chart) %>%</p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Average Loss</p>
                    <p class="font-medium mt-1"><%= calculate_avg_loss(@all_trades_for_chart) %>%</p>
                  </div>
                  <div>
                    <p class="text-muted-foreground">Profit Factor</p>
                    <p class="font-medium mt-1"><%= calculate_profit_factor(@all_trades_for_chart) %></p>
                  </div>
                </div>
              </.card_content>
            </.card>
          </div>
        </div>
      <% else %>
        <%!-- Handles the case where backtest is nil after mount error --%>
        <div class="flex flex-col items-center justify-center h-64 text-center">
          <p class="text-lg text-muted-foreground">Loading backtest details or backtest not found.</p>
          <.link navigate={~p"/strategies"} class="mt-4">
            <.button variant="outline">Return to Strategies</.button>
          </.link>
        </div>
      <% end %>
    </div>
    """
  end

  # --- Event Handlers for Trade Pagination ---
  @impl true
  def handle_event("trade_page_changed", %{"page" => page, "backtest_id" => backtest_id_str}, socket) when is_integer(page) do
    # Handle the case when page is already an integer
    if backtest_id_str == to_string(socket.assigns.backtest.id) do
      trades = TradeContext.list_trades_for_backtest_paginated(socket.assigns.backtest.id, page, @trades_page_size)
      updated_backtest = Map.put(socket.assigns.backtest, :trades, trades)

      {:noreply,
        socket
        |> assign(:backtest, updated_backtest)
        |> assign(:trade_page, page)
      }
    else
      Logger.warning("Mismatched backtest_id in trade_page_changed event. Expected #{socket.assigns.backtest.id}, got #{backtest_id_str}")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("trade_page_changed", %{"page" => page_str, "backtest_id" => backtest_id_str}, socket) when is_binary(page_str) do
    # Ensure backtest_id from event matches the one in the socket
    # to prevent potential issues if the component ID is reused incorrectly.
    if backtest_id_str == to_string(socket.assigns.backtest.id) do
      case Integer.parse(page_str) do
        {page, ""} when page > 0 ->
          trades = TradeContext.list_trades_for_backtest_paginated(socket.assigns.backtest.id, page, @trades_page_size)
          updated_backtest = Map.put(socket.assigns.backtest, :trades, trades)

          {:noreply,
            socket
            |> assign(:backtest, updated_backtest)
            |> assign(:trade_page, page)
          }
        _ ->
          Logger.warning("Invalid page number received: #{page_str}")
          {:noreply, socket}
      end
    else
      Logger.warning("Mismatched backtest_id in trade_page_changed event. Expected #{socket.assigns.backtest.id}, got #{backtest_id_str}")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("chart-initialized", _params, socket) do
    # Simply acknowledge the event from the chart component
    {:noreply, socket}
  end

  # --- Helper functions ---
  defp side_color(:long), do: "text-green-600 dark:text-green-400"
  defp side_color(:short), do: "text-red-600 dark:text-red-400"
  defp side_color(_), do: ""

  defp pnl_color(value), do: FormatterUtils.color_class(value)

  defp status_color(:completed), do: "text-green-600 dark:text-green-400"
  defp status_color(:running), do: "text-blue-600 dark:text-blue-400"
  defp status_color(:pending), do: "text-yellow-600 dark:text-yellow-400"
  defp status_color(:failed), do: "text-red-600 dark:text-red-400"
  defp status_color(_), do: "text-muted-foreground"

  defp format_time_range(start_time, end_time) do
    start_str = FormatterUtils.format_datetime(start_time)
    end_str = FormatterUtils.format_datetime(end_time)
    "#{start_str} - #{end_str}"
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

  # Calculate win rate
  defp calculate_win_rate(trades) do
    if !trades || Enum.empty?(trades) do
      "0.00"
    else
      profitable_trades = Enum.count(trades, fn trade -> Decimal.compare(trade.pnl, Decimal.new(0)) == :gt end)
      win_rate = profitable_trades / length(trades) * 100
      :erlang.float_to_binary(win_rate, decimals: 2)
    end
  end

  # Calculate average profit percentage for winning trades
  defp calculate_avg_profit(trades) do
    if !trades || Enum.empty?(trades) do
      "0.00"
    else
      profitable_trades = Enum.filter(trades, fn trade -> Decimal.compare(trade.pnl, Decimal.new(0)) == :gt end)

      if length(profitable_trades) > 0 do
        avg_profit_pct =
          profitable_trades
          |> Enum.map(fn trade -> Decimal.to_float(trade.pnl_percentage) * 100 end)
          |> Enum.sum()
          |> Kernel./(length(profitable_trades))

        :erlang.float_to_binary(avg_profit_pct, decimals: 2)
      else
        "0.00"
      end
    end
  end

  # Calculate average loss percentage for losing trades
  defp calculate_avg_loss(trades) do
    if !trades || Enum.empty?(trades) do
      "0.00"
    else
      losing_trades = Enum.filter(trades, fn trade -> Decimal.compare(trade.pnl, Decimal.new(0)) == :lt end)

      if length(losing_trades) > 0 do
        avg_loss_pct =
          losing_trades
          |> Enum.map(fn trade -> Decimal.to_float(trade.pnl_percentage) * 100 * -1 end) # Make positive for display
          |> Enum.sum()
          |> Kernel./(length(losing_trades))

        :erlang.float_to_binary(avg_loss_pct, decimals: 2)
      else
        "0.00"
      end
    end
  end

  # Calculate profit factor (total profits / total losses)
  defp calculate_profit_factor(trades) do
    if !trades || Enum.empty?(trades) do
      "0.00"
    else
      total_profit =
        trades
        |> Enum.filter(fn trade -> Decimal.compare(trade.pnl, Decimal.new(0)) == :gt end)
        |> Enum.reduce(Decimal.new(0), fn trade, acc -> Decimal.add(acc, trade.pnl) end)

      total_loss =
        trades
        |> Enum.filter(fn trade -> Decimal.compare(trade.pnl, Decimal.new(0)) == :lt end)
        |> Enum.reduce(Decimal.new(0), fn trade, acc -> Decimal.add(acc, Decimal.abs(trade.pnl)) end)

      if Decimal.compare(total_loss, Decimal.new(0)) == :gt do
        profit_factor = Decimal.div(total_profit, total_loss)
        Decimal.round(profit_factor, 2) |> Decimal.to_string()
      else
        "∞" # Infinity symbol when no losses
      end
    end
  end
end
