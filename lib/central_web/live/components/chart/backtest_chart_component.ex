defmodule CentralWeb.Live.Components.Chart.BacktestChartComponent do
  @moduledoc """
  A LiveComponent responsible for displaying a chart specifically for backtest results.

  This component acts as a parent controller for the generic `ChartComponent`.
  Its primary roles are:
  - Receiving the `backtest` and associated `trades` assigns.
  - Loading the initial candle data (`chart_data`) constrained by the backtest's time range.
  - Indexing and filtering trades relevant to the displayed candle range.
  - Formatting trades into markers suitable for the chart.
  - Passing the initial `chart_data` and `chart_options` (including formatted trades)
    to the child `ChartComponent`.
  - Handling the `load-historical-data` event triggered by the chart's JS hook
    when the user scrolls back in time, fetching older candle data and associated trades
    within the backtest's bounds.
  - Sending fetched historical data back to the JS hook via `push_event`.
  - Triggering the initial data push in the child `ChartComponent` using `send_update`
    once its own data loading is complete.
  """
  use Phoenix.LiveComponent
  require Logger

  alias CentralWeb.Live.Components.Chart.ChartComponent
  alias Central.Backtest.Contexts.MarketDataContext
  alias CentralWeb.Live.Components.Chart.ChartDataFormatter
  alias Central.Helpers.TimeframeHelper

  @doc """
  Renders a chart specifically for a backtest result, constraining data to the backtest period
  and optionally displaying trade markers.

  It delegates the core chart rendering to the generic `ChartComponent`.

  ## Attributes
    - id: Component ID (required)
    - backtest: Backtest struct (required)
    - height: Chart height (default: "500px")
    - theme: Chart theme (default: "dark")
    - show_trades: Whether to display trade markers (default: false)
    - trades: List of trades to display as markers (default: [])
  """

  # Constants for performance tuning
  @initial_candle_limit 500  # Maximum candles to load initially
  @historical_chunk_size 200 # Size of each historical data chunk on scroll
  @max_trade_batch 500       # Maximum trades to send in one batch for initial load

  # Helper function to get the later of two DateTimes
  defp max_datetime(dt1, dt2) do
    case DateTime.compare(dt1, dt2) do
      :gt -> dt1
      _ -> dt2
    end
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      chart_data: nil,
      loading: true,
      trades_by_timestamp: %{},
      chart_options: %{}
    )}
  end

  @impl true
  def update(assigns, socket) do
    # Get the new backtest from incoming assigns
    new_backtest = assigns[:backtest]
    # Safely get the old backtest ID from the current socket state
    old_backtest_id = socket.assigns[:backtest] && socket.assigns.backtest.id

    # Determine if data needs loading *before* assigning new assigns
    needs_data_load? =
      new_backtest && # Need a new backtest to potentially load
      (old_backtest_id != new_backtest.id || # ID changed
       is_nil(socket.assigns.chart_data))   # Or no data loaded yet

    # Assign all incoming assigns to the socket *now*
    socket = assign(socket, assigns)

    # Index trades by timestamp for efficient filtering when we load more data chunks
    socket =
      if assigns[:trades] && (old_backtest_id != new_backtest.id || socket.assigns[:trades_by_timestamp] == %{}) do
        trades_by_timestamp = index_trades_by_timestamp(assigns.trades)
        assign(socket, trades_by_timestamp: trades_by_timestamp)
      else
        socket
      end

    # Perform data loading if needed, using the now-assigned backtest
    if needs_data_load? do
      backtest = socket.assigns.backtest # Guaranteed to exist due to the check above

      # Calculate the start time for the initial limited query
      initial_start_time =
        case TimeframeHelper.timeframe_to_seconds(backtest.timeframe) do
          # Handle the integer return value directly
          seconds when seconds > 0 ->
            calculated_start = DateTime.add(backtest.end_time, -seconds * @initial_candle_limit, :second)
            # Ensure we don't go earlier than the actual backtest start time
            max_datetime(calculated_start, backtest.start_time)

          # Handle the 0 case (error or unknown timeframe)
          _ ->
            # Fallback if timeframe is invalid or limit calculation fails
            Logger.warning("Could not calculate initial start time for backtest chart #{backtest.id} (timeframe: #{backtest.timeframe}). Using full backtest start time.")
            backtest.start_time
        end

      Logger.debug("[BacktestChartComponent] Loading initial data (limit #{@initial_candle_limit}) for backtest ID: #{backtest.id}")
      Logger.debug("[BacktestChartComponent] Query range: #{inspect(initial_start_time)} to #{inspect(backtest.end_time)}")

      # Use the optimized query with limit
      limited_candles = MarketDataContext.get_candles_with_limit(
        backtest.symbol,
        backtest.timeframe,
        initial_start_time,
        backtest.end_time,
        limit: @initial_candle_limit,
        order_by: :asc
      )

      if Enum.empty?(limited_candles) do
        Logger.warning("No candle data found for #{backtest.symbol}/#{backtest.timeframe} from #{inspect initial_start_time} to #{inspect backtest.end_time}")
      end

      Logger.debug("[BacktestChartComponent] Fetched #{length(limited_candles)} candles with optimized query")

      # Format the limited data
      formatted_data = ChartDataFormatter.format_chart_data(limited_candles)

      # Filter trades relevant ONLY to the initial candle range
      initial_trades =
        if socket.assigns.show_trades do
          filtered_trades = filter_trades_for_range(socket.assigns.trades_by_timestamp, limited_candles, @max_trade_batch)
          filtered_trades
        else
          []
        end

      # Format trades for the chart
      formatted_trades = format_trades_for_chart(initial_trades)

      # Build options for the chart
      chart_options = build_chart_opts(socket.assigns, formatted_trades)

      # Update socket with loaded data and set loading to false
      socket = assign(socket,
        chart_data: formatted_data,
        loading: false,
        chart_options: chart_options
      )

      # <<< MOVED INSIDE: Trigger data push in child component >>>
      send_update(ChartComponent, id: "#{socket.assigns.id}-tradingview-chart", push_data: true)

      {:ok, socket}
    else
      # If not loading, just return the socket with potentially updated assigns (like :loading from parent)
      {:ok, socket}
    end
  end

  # -- Event Handling --

  @impl true
  def handle_event("load-historical-data", payload, socket) do
    %{"oldestTimeISO" => oldest_time_iso, "limit" => limit} = payload
    backtest = socket.assigns.backtest
    chart_id = "#{socket.assigns.id}-tradingview-chart"

    # Use a safe default if limit is missing or invalid
    safe_limit = if is_integer(limit), do: min(limit, @historical_chunk_size), else: @historical_chunk_size

    case DateTime.from_iso8601(oldest_time_iso) do
      {:ok, oldest_time, _offset} ->
        Logger.debug("[BacktestChartComponent][#{chart_id}] Handling load-historical-data before #{inspect oldest_time}, requested limit: #{safe_limit}")

        # Use the optimized query with limit and descending order (newest first)
        historical_candles = MarketDataContext.get_candles_with_limit(
          backtest.symbol,
          backtest.timeframe,
          backtest.start_time,  # Use the backtest start time as lower bound
          oldest_time,          # Use the oldest visible candle as upper bound
          limit: safe_limit,
          order_by: :desc       # Get newest candles first (closest to oldest_time)
        )

        if Enum.empty?(historical_candles) do
          Logger.warning("[BacktestChartComponent][#{chart_id}] No historical candles found for range before #{inspect oldest_time}")
          push_event(socket, "historical-data-loaded", %{chartId: chart_id, data: [], trades: []})
        else
          # Format fetched candles (keep newest-first order for the frontend)
          formatted_data = ChartDataFormatter.format_chart_data(historical_candles)

          # Find trades within the time range of the fetched candles
          relevant_trades =
            if socket.assigns.show_trades do
              filtered_trades = filter_trades_for_range(socket.assigns.trades_by_timestamp, historical_candles, @max_trade_batch)
              filtered_trades
            else
              []
            end

          formatted_trades = format_trades_for_chart(relevant_trades)

          Logger.debug("[BacktestChartComponent][#{chart_id}] Returning #{length(formatted_data)} candles and #{length(formatted_trades)} trades")

          # Push the historical data (newest first, as expected by frontend)
          push_event(socket, "historical-data-loaded", %{
            chartId: chart_id,
            data: formatted_data,
            trades: formatted_trades
          })
        end

      {:error, reason} ->
        Logger.error("[BacktestChartComponent][#{chart_id}] Invalid oldestTimeISO '#{oldest_time_iso}': #{inspect reason}")
        # Push back empty data on error
        push_event(socket, "historical-data-loaded", %{chartId: chart_id, data: [], trades: []})
    end

    {:noreply, socket}
  end

  # Index trades by timestamp ranges for efficient filtering
  defp index_trades_by_timestamp(trades) do
    if is_nil(trades) || Enum.empty?(trades) do
      %{}
    else
      # Use Unix timestamps as keys for efficient lookup
      trades
      |> Enum.reduce(%{}, fn trade, acc ->
        # Add entry timestamp
        entry_ts =
          if trade.entry_time do
            DateTime.to_unix(trade.entry_time)
          else
            nil
          end

        # Add exit timestamp
        exit_ts =
          if trade.exit_time do
            DateTime.to_unix(trade.exit_time)
          else
            nil
          end

        # Skip trades with invalid timestamps
        if is_nil(entry_ts) && is_nil(exit_ts) do
          acc
        else
          # Index by entry time
          acc1 =
            if entry_ts do
              Map.update(acc, entry_ts, [trade], fn trades -> [trade | trades] end)
            else
              acc
            end

          # Index by exit time (if different from entry)
          if exit_ts && exit_ts != entry_ts do
            Map.update(acc1, exit_ts, [trade], fn trades -> [trade | trades] end)
          else
            acc1
          end
        end
      end)
    end
  end

  # Helper to filter trades based on a list of candles using timestamp index
  defp filter_trades_for_range(trades_by_timestamp, candles, limit) do
    if Enum.empty?(candles) || trades_by_timestamp == %{} do
      []
    else
      # Get the time range from the candle list (candles might be ascending or descending)
      timestamps = Enum.map(candles, fn candle -> DateTime.to_unix(candle.timestamp) end)
      {min_ts, max_ts} = Enum.min_max(timestamps)

      # Expand range slightly to catch trades that might be at the exact boundaries
      min_ts = max(min_ts - 1, 0)  # Ensure we don't go negative
      max_ts = max_ts + 1

      # Find all trades in the time range
      matched_trades =
        min_ts..max_ts
        |> Enum.reduce(MapSet.new(), fn ts, acc ->
          if trades = Map.get(trades_by_timestamp, ts) do
            # Add all trades at this timestamp to our results
            Enum.reduce(trades, acc, fn trade, acc -> MapSet.put(acc, trade) end)
          else
            acc
          end
        end)
        |> MapSet.to_list()  # Convert MapSet back to list

      # Apply limit if specified
      if limit && length(matched_trades) > limit do
        Logger.warning("[BacktestChartComponent] Limiting trades from #{length(matched_trades)} to #{limit}")
        Enum.take(matched_trades, limit)
      else
        matched_trades
      end
    end
  end

  # Format trades for the TradingView chart
  defp format_trades_for_chart(trades) do
    formatted = Enum.map(trades, fn trade ->
      %{
        # Convert times to UNIX timestamps
        time: DateTime.to_unix(trade.entry_time),
        # Include original entry time for debugging
        entry_time: DateTime.to_unix(trade.entry_time),
        # Convert side to lowercase string (handle both atom and string cases)
        side: trade.side |> to_string() |> String.downcase(),
        # Safely convert Decimal prices to floats (handles both Decimal and float inputs)
        entry_price: safe_to_float(trade.entry_price),
        quantity: safe_to_float(trade.quantity),
        # Include the ID for reference
        id: trade.id,
        # Include exit data if available
        exit_time: trade.exit_time && DateTime.to_unix(trade.exit_time),
        exit_price: trade.exit_price && safe_to_float(trade.exit_price),
        # Optional metadata like PnL if available
        pnl: trade.pnl && safe_to_float(trade.pnl),
        pnl_percentage: trade.pnl_percentage && safe_to_float(trade.pnl_percentage)
      }
    end)

    # Print first trade for debugging
    if length(formatted) > 0 do
      :ok # Placeholder if needed, or just remove the if block if nothing else goes here
    end

    formatted
  end

  # Helper to safely convert values to float
  defp safe_to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp safe_to_float(num) when is_number(num), do: num
  defp safe_to_float(_), do: 0.0

  # Build chart options
  defp build_chart_opts(_assigns, trades_override) do
    trades_to_use = trades_override

    chart_opts = Map.new()
    |> Map.put(:trades, trades_to_use)
    |> Map.put(:backtest_mode, true)

    chart_opts
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="w-full bg-background relative">
      <.live_component
        module={ChartComponent}
        id={"#{@id}-tradingview-chart"}
        chart_id={"#{@id}-tradingview-chart"}
        chart_type={:backtest}
        symbol={@backtest.symbol}
        timeframe={@backtest.timeframe}
        theme={@theme}
        height={@height}
        start_time_limit={@backtest.start_time}
        end_time_limit={@backtest.end_time}
        loading={@loading}
        chart_data={@chart_data}
        opts={@chart_options}
      />
    </div>
    """
  end
end
