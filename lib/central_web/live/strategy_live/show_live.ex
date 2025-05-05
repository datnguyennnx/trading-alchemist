defmodule CentralWeb.StrategyLive.ShowLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext
  alias Central.Backtest.Contexts.BacktestContext
  alias Central.Backtest.Indicators

  require Logger

  # Import UI components
  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Icon

  import CentralWeb.Components.UI.AlertDialog

  # Import strategy components
  alias CentralWeb.StrategyLive.Components.BacktestHistory
  alias CentralWeb.StrategyLive.Components.TradingRules
  alias CentralWeb.StrategyLive.Components.LatestPerformance
  alias CentralWeb.StrategyLive.Components.BacktestForm
  alias CentralWeb.BacktestLive.Utils.FormatterUtils

  @page_size 10

  def mount(%{"id" => id}, _session, socket) do
    strategy = StrategyContext.get_strategy!(id)

    page = 1
    {backtests, backtests_count} = fetch_paginated_backtests(id, page, @page_size)

    # Get the most recent *completed* backtest for quick stats (fetch separately)
    recent_backtest = BacktestContext.get_most_recent_completed_backtest(id) |> maybe_add_pnl()

    # Initialize backtest form with default values
    default_values = %{
      "initial_balance" => "10000.0",
      "position_size" => "2.0"
    }

    # Default dates for backtest form
    start_time = default_start_time_datetime()
    end_time = default_end_time_datetime()

    {:ok,
     socket
     |> assign(:strategy, strategy)
     |> assign(:backtests, backtests) # Now contains only the current page
     |> assign(:page, page)
     |> assign(:page_size, @page_size)
     |> assign(:backtests_count, backtests_count)
     |> assign(:recent_backtest, recent_backtest) # Assign potentially nil recent backtest
     |> assign(:indicators, Indicators.list_indicators())
     |> assign(:show_backtest_form, true)
     |> assign(:form, to_form(default_values))
     |> assign(:start_time, start_time)
     |> assign(:end_time, end_time)
     |> assign(:page_title, strategy.name)}
  end

  defp fetch_paginated_backtests(strategy_id, page, page_size) do
    offset = (page - 1) * page_size
    backtests_raw = BacktestContext.list_backtests_for_strategy(strategy_id, limit: page_size, offset: offset)
    backtests_count = BacktestContext.count_backtests_for_strategy(strategy_id)

    # Calculate additional fields for the current page of backtests
    backtests =
      Enum.map(backtests_raw, fn backtest ->
        backtest
        |> maybe_add_pnl()
      end)

    {backtests, backtests_count}
  end

  # Helper to add PnL fields to a single backtest map
  defp maybe_add_pnl(nil), do: nil
  defp maybe_add_pnl(backtest) do
    total_pnl = calculate_total_pnl(backtest)
    total_pnl_percentage = calculate_pnl_percentage(backtest)
    total_trades = Map.get(backtest, :total_trades, "N/A") # Keep placeholder or improve later

    backtest
    |> Map.put(:total_pnl, total_pnl)
    |> Map.put(:total_pnl_percentage, total_pnl_percentage)
    |> Map.put(:total_trades, total_trades)
  end

  # Helper functions for PnL calculation (assuming these exist or are defined below)
  defp calculate_total_pnl(backtest) do
    # Return nil if final_balance is missing
    if is_nil(backtest.final_balance) or is_nil(backtest.initial_balance) do
      nil
    else
      Decimal.sub(backtest.final_balance, backtest.initial_balance)
    end
  end

  defp calculate_pnl_percentage(backtest) do
    initial = backtest.initial_balance
    # Get total_pnl, which might be nil now
    total_pnl = calculate_total_pnl(backtest)

    # Check for nil pnl or invalid initial balance before calculating percentage
    if is_nil(total_pnl) or is_nil(initial) or Decimal.compare(initial, Decimal.new(0)) != :gt do
      nil
    else
      Decimal.div(total_pnl, initial) |> Decimal.mult(100) |> Decimal.round(2)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <!-- Strategy Header -->
      <div class="flex flex-col md:flex-row justify-between items-start gap-4 mb-6">
        <div>
          <h1 class="text-2xl font-bold">{@strategy.name}</h1>
          <div class="flex flex-wrap items-center gap-4 mt-2 text-sm text-muted-foreground">
            <div class="flex items-center gap-1">
              <p>Symbol:</p>
              <p class="font-medium">{@strategy.config["symbol"]}</p>
            </div>
            <div class="flex items-center gap-1">
              <p>Timeframe:</p>
              <p class="font-medium">{@strategy.config["timeframe"]}</p>
            </div>
            <div class="flex items-center gap-1">
              <p>Risk:</p>
              <p class="font-medium">{@strategy.config["risk_per_trade"]}%</p>
            </div>
            <div class="flex items-center gap-1">
              <p>Created:</p>
              <p class="font-medium">{FormatterUtils.format_datetime(@strategy.inserted_at)}</p>
            </div>
            <div class="flex items-center gap-1">
              <p>Last Modified:</p>
              <p class="font-medium">{FormatterUtils.format_datetime(@strategy.updated_at)}</p>
            </div>
            <%= if @strategy.description && @strategy.description != "" do %>
              <div class="flex items-center gap-1">
                <p>Description:</p>
                <p class="font-medium">{@strategy.description}</p>
              </div>
            <% end %>
          </div>
        </div>

        <div class="flex items-center space-x-2">
          <.link navigate={~p"/strategies/#{@strategy.id}/edit"}>
            <.button variant="outline" size="sm">
              <.icon name="hero-pencil-square" class="h-4 w-4 mr-2" /> Edit Strategy
            </.button>
          </.link>
          <.alert_dialog id="delete-strategy-dialog">
            <.alert_dialog_trigger builder={%{id: "delete-strategy-dialog", open: false}}>
              <.button variant="outline" size="sm">
                <.icon name="hero-trash" class="h-4 w-4 mr-2" /> Delete Strategy
              </.button>
            </.alert_dialog_trigger>
            <.alert_dialog_content builder={%{id: "delete-strategy-dialog", open: false}}>
              <.alert_dialog_header>
                <.alert_dialog_title>Delete Strategy</.alert_dialog_title>
                <.alert_dialog_description>
                  Are you sure you want to delete this strategy? This action cannot be undone.
                </.alert_dialog_description>
              </.alert_dialog_header>
              <.alert_dialog_footer>
                <.alert_dialog_cancel builder={%{id: "delete-strategy-dialog", open: false}}>
                  Cancel
                </.alert_dialog_cancel>
                <.button variant="destructive" phx-click="delete_strategy">
                  Delete
                </.button>
              </.alert_dialog_footer>
            </.alert_dialog_content>
          </.alert_dialog>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-6 gap-6">
        <!-- Left Column: Backtest Controls & History -->
        <div class="space-y-6 col-span-full lg:col-span-4">
          <.live_component
            module={BacktestForm}
            id="backtest-form-component"
            form={@form}
            start_time={@start_time}
            end_time={@end_time}
            strategy_id={@strategy.id}
          />

          <!-- Backtest History -->
          <.live_component
            module={BacktestHistory}
            id="backtest-history"
            backtest_data={@backtests}
            current_page={@page}
            page_size={@page_size}
            total_entries={@backtests_count}
            on_page_change="change_backtest_page"
          />
        </div>

        <!-- Right Column: Strategy Information -->
        <div class="space-y-6 col-span-full lg:col-span-2">
          <!-- Latest Performance -->
          <%= if @recent_backtest do %>
            <.live_component
              module={LatestPerformance}
              id="latest-performance"
              backtest={@recent_backtest}
            />
          <% end %>

          <!-- Trading Rules -->
          <.live_component
            module={TradingRules}
            id="trading-rules"
            strategy={@strategy}
            indicators={@indicators}
          />
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

  def handle_event("run_backtest", params, socket) do
    strategy = socket.assigns.strategy

    # Extract and parse form values
    initial_balance = parse_decimal(params["initial_balance"], "10000.0")
    position_size = parse_decimal(params["position_size"], "2.0")

    # Parse dates or set defaults
    start_time = parse_datetime(params["start_time"], socket.assigns.start_time)
    end_time = parse_datetime(params["end_time"], socket.assigns.end_time)

    # Create backtest parameters
    backtest_params = %{
      strategy_id: strategy.id,
      symbol: strategy.config["symbol"],
      timeframe: strategy.config["timeframe"],
      start_time: start_time,
      end_time: end_time,
      initial_balance: initial_balance,
      position_size: position_size,
      status: :pending,
      user_id: strategy.user_id,
      metadata: %{
        "position_size" => Decimal.to_string(position_size),
        "progress" => 0
      }
    }

    # Create a changeset to validate params
    changeset =
      Central.Backtest.Schemas.Backtest.changeset(
        %Central.Backtest.Schemas.Backtest{},
        backtest_params
      )

    if changeset.valid? do
      # Directly create and run the backtest without confirmation
      case BacktestContext.create_backtest(backtest_params) do
        {:ok, backtest} ->
          # Start the backtest in the background
          Central.Backtest.Workers.BacktestRunnerWorker.perform_async(%{
            "backtest_id" => backtest.id
          })

          # Subscribe to backtest updates
          Phoenix.PubSub.subscribe(Central.PubSub, "backtest:#{backtest.id}")

          # Refetch the first page of backtests to show the new one
          {updated_backtests, updated_count} = fetch_paginated_backtests(strategy.id, 1, @page_size)

          {:noreply,
           socket
           |> assign(
             backtests: updated_backtests,
             backtests_count: updated_count,
             page: 1 # Reset to page 1
           )
           |> put_flash(:info, "Backtest started successfully! Redirecting...")
           |> push_navigate(to: ~p"/backtest/#{backtest.id}")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to start backtest: #{error_messages(changeset)}")
           |> assign(
             :form,
             to_form(Map.merge(socket.assigns.form.data, %{errors: changeset.errors}))
           )}
      end
    else
      errors =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)

      error_message =
        errors
        |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
        |> Enum.join("; ")

      {:noreply,
       socket
       |> put_flash(:error, "Invalid backtest parameters: #{error_message}")
       |> assign(:form, to_form(Map.merge(socket.assigns.form.data, %{errors: errors})))}
    end
  end

  def handle_event("cancel_backtest", _, socket) do
    {:noreply,
     socket
     |> assign(:show_backtest_confirm, false)
     |> assign(:backtest_params, nil)
     |> push_event("phx-hide-alert-dialog", %{id: "confirm-backtest-dialog"})}
  end

  # DateTimePicker events
  def handle_event(
        "datetime-update",
        %{"name" => "start_time", "datetime" => datetime_str},
        socket
      ) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} ->
        {:noreply, assign(socket, :start_time, datetime)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("datetime-update", %{"name" => "end_time", "datetime" => datetime_str}, socket) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} ->
        {:noreply, assign(socket, :end_time, datetime)}

      _ ->
        {:noreply, socket}
    end
  end

  # Handler for date_time_picker_change event
  def handle_event(
        "date_time_picker_change",
        %{"name" => "start_time", "value" => datetime_str},
        socket
      ) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} ->
        {:noreply, assign(socket, :start_time, datetime)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "date_time_picker_change",
        %{"name" => "end_time", "value" => datetime_str},
        socket
      ) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} ->
        {:noreply, assign(socket, :end_time, datetime)}

      _ ->
        {:noreply, socket}
    end
  end

  # Catch-all handler for date_time_picker_change
  def handle_event("date_time_picker_change", _params, socket) do
    {:noreply, socket}
  end

  # Handle page change for backtest history
  def handle_event("change_backtest_page", %{"page" => page}, socket) when is_integer(page) do
    strategy_id = socket.assigns.strategy.id
    {backtests, _count} = fetch_paginated_backtests(strategy_id, page, socket.assigns.page_size)

    {:noreply,
     socket
     |> assign(:backtests, backtests)
     |> assign(:page, page)}
  end

  # Helper functions for parsing form values
  defp parse_decimal(value, default) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _ -> Decimal.new(default)
    end
  end

  defp parse_decimal(_, default), do: Decimal.new(default)

  defp parse_datetime(nil, default), do: default
  defp parse_datetime("", default), do: default

  defp parse_datetime(datetime_string, default) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> default
    end
  end

  defp parse_datetime(_, default), do: default

  # Helper functions to set reasonable default times as DateTime objects
  defp default_start_time_datetime do
    # Default to 30 days ago
    DateTime.utc_now()
    |> DateTime.add(-30, :day)
    |> DateTime.truncate(:second)
  end

  defp default_end_time_datetime do
    # Default to now
    DateTime.utc_now()
    |> DateTime.truncate(:second)
  end

  # Format changeset errors for display
  defp error_messages(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end
end
