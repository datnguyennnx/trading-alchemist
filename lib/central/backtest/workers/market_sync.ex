defmodule Central.Backtest.Workers.MarketSync do
  @moduledoc """
  GenServer for synchronizing market data in the background.
  Periodically fetches new candles for configured symbols and timeframes.
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias Central.Backtest.Services.Binance.Client, as: BinanceClient
  alias Central.Backtest.Schemas.MarketData
  alias Central.Config.DateTime, as: DateTimeConfig
  alias Central.Repo

  # 1 hour by default
  @default_sync_interval 60 * 60 * 1000

  # Default symbols and timeframes if not specified
  @default_symbols ["BTCUSDT"]
  @default_timeframes ["1m", "5m", "15m", "1h", "4h", "1d"]

  # API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an immediate sync for the given symbol and timeframe.
  If no symbol or timeframe is provided, uses the defaults.
  """
  def trigger_sync(symbol \\ nil, timeframe \\ nil) do
    GenServer.cast(__MODULE__, {:sync, symbol, timeframe})
  end

  @doc """
  Gets the current sync status including the next scheduled sync time.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # CALLBACKS

  @impl GenServer
  def init(opts) do
    Logger.info("Starting Market Sync Worker")

    symbols = Keyword.get(opts, :symbols, @default_symbols)
    timeframes = Keyword.get(opts, :timeframes, @default_timeframes)
    sync_interval = Keyword.get(opts, :sync_interval, @default_sync_interval)

    # Schedule initial sync
    # Start immediately
    schedule_sync(0)

    {:ok,
     %{
       symbols: symbols,
       timeframes: timeframes,
       sync_interval: sync_interval,
       last_sync_time: nil,
       next_sync_time: DateTimeConfig.now(),
       sync_running: false,
       last_sync_result: nil,
       syncing_markets: %{}
     }}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    {:reply,
     Map.take(state, [:last_sync_time, :next_sync_time, :sync_running, :last_sync_result]), state}
  end

  @impl GenServer
  def handle_cast({:sync, nil, nil}, state) do
    # If no specific symbol or timeframe, sync all configured pairs
    unless state.sync_running do
      Logger.info("Starting scheduled market data sync")

      # Mark sync as running
      updated_state = %{state | sync_running: true, last_sync_time: DateTimeConfig.now()}

      # Log the symbols and timeframes being synced
      Logger.info(
        "Syncing market data for symbols: #{inspect(state.symbols)}, timeframes: #{inspect(state.timeframes)}"
      )

      # Start the sync process
      Task.start(fn ->
        try do
          results = sync_market_data(state.symbols, state.timeframes)
          # Send the results back to the GenServer
          GenServer.cast(__MODULE__, {:sync_complete, :ok, results})
        catch
          kind, reason ->
            stacktrace = __STACKTRACE__
            Logger.error("Market sync failed: #{inspect(reason)}")
            GenServer.cast(__MODULE__, {:sync_complete, :error, {kind, reason, stacktrace}})
        end
      end)

      {:noreply, updated_state}
    else
      Logger.warning("Skipping market data sync - previous sync still running")
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:sync, symbol, timeframe}, state) do
    # Sync specific symbol/timeframe combination
    symbols = if symbol, do: [symbol], else: state.symbols
    timeframes = if timeframe, do: [timeframe], else: state.timeframes

    unless state.sync_running do
      Logger.info(
        "Starting manual market data sync - symbols: #{inspect(symbols)}, timeframes: #{inspect(timeframes)}"
      )

      # Mark sync as running
      updated_state = %{state | sync_running: true, last_sync_time: DateTimeConfig.now()}

      # Start the sync process
      Task.start(fn ->
        try do
          results = sync_market_data(symbols, timeframes)
          # Send the results back to the GenServer
          GenServer.cast(__MODULE__, {:sync_complete, :ok, results})
        catch
          kind, reason ->
            stacktrace = __STACKTRACE__
            Logger.error("Market sync failed: #{inspect(reason)}")
            GenServer.cast(__MODULE__, {:sync_complete, :error, {kind, reason, stacktrace}})
        end
      end)

      {:noreply, updated_state}
    else
      Logger.warning("Skipping manual market data sync - previous sync still running")
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:sync_complete, status, results}, state) do
    # Update state with sync results
    new_state = %{state | sync_running: false, last_sync_result: {status, results}}

    case status do
      :ok ->
        sync_counts = count_synced_items(results)

        duration_ms =
          case state.last_sync_time do
            nil -> 0
            start_time -> DateTime.diff(DateTimeConfig.now(), start_time, :millisecond)
          end

        Logger.info(
          "Market data sync completed successfully - candles: #{sync_counts.total}, duration: #{duration_ms}ms"
        )

      :error ->
        Logger.error("Market data sync failed: #{inspect(results)}")
    end

    # Schedule next sync if this was a scheduled (not manual) sync
    schedule_next_sync(new_state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:perform_sync, state) do
    # Trigger a sync (will be ignored if one is already running)
    GenServer.cast(self(), {:sync, nil, nil})
    {:noreply, state}
  end

  # PRIVATE FUNCTIONS

  defp sync_market_data(symbols, timeframes) do
    for symbol <- symbols, timeframe <- timeframes do
      Task.async(fn ->
        # Get the current GenServer state and pass it rather than the PID
        state = :sys.get_state(__MODULE__)
        # Add a result key to make the result compatible with count_synced_items
        sync_result = sync_single_market({symbol, timeframe}, state)
        # Return a map with market_key and result
        %{
          market_key: {symbol, timeframe},
          result:
            case sync_result do
              # No error but no data processed
              {:noreply, _state} -> {:ok, 0}
              # Pass through any other results
              other -> other
            end
        }
      end)
    end
    # 5 minute timeout for all tasks
    |> Task.await_many(300_000)
  end

  defp sync_single_market({symbol, timeframe} = market_key, state) do
    # Check if we're already syncing this market
    if Map.get(state.syncing_markets, market_key) do
      Logger.warning("Skipping sync for #{symbol}/#{timeframe} - previous sync still running")
      {:noreply, state}
    else
      Logger.info("Starting sync for #{symbol}/#{timeframe}",
        symbol: symbol,
        timeframe: timeframe
      )

      # Get the time range to sync
      {fetch_start_time, fetch_end_time} = get_sync_time_range(symbol, timeframe)

      start_time = DateTimeConfig.format(fetch_start_time)
      end_time = DateTimeConfig.format(fetch_end_time)

      Logger.info("Fetching data from #{start_time} to #{end_time}",
        symbol: symbol,
        timeframe: timeframe,
        start_time: start_time,
        end_time: end_time
      )

      # Mark this market as syncing
      new_state = put_in(state, [:syncing_markets, market_key], true)

      # Start the sync process in a Task
      Task.start(fn ->
        sync_start_time = DateTimeConfig.now()

        # Fetch the data from Binance with retries
        case fetch_with_retries(symbol, timeframe, fetch_start_time, fetch_end_time) do
          {:ok, market_data} ->
            # Success - insert the data into the database
            case upsert_market_data(market_data) do
              {:ok, count} ->
                # Calculate duration in milliseconds
                sync_duration_ms =
                  DateTime.diff(DateTimeConfig.now(), sync_start_time, :millisecond)

                # Send a message back to the GenServer that sync is complete
                send(self(), {:sync_complete, market_key, :success, count, sync_duration_ms})

              {:error, reason} ->
                Logger.error("Failed to insert market data: #{inspect(reason)}",
                  symbol: symbol,
                  timeframe: timeframe,
                  error: inspect(reason)
                )

                send(self(), {:sync_complete, market_key, :error, reason, 0})
            end

          {:error, reason} ->
            # Error fetching data
            Logger.error("Failed to fetch market data: #{inspect(reason)}",
              symbol: symbol,
              timeframe: timeframe,
              error: inspect(reason)
            )

            send(self(), {:sync_complete, market_key, :error, reason, 0})
        end
      end)

      {:noreply, new_state}
    end
  end

  defp fetch_with_retries(symbol, timeframe, start_time, end_time, retries \\ 3) do
    case BinanceClient.download_historical_data(symbol, timeframe, start_time, end_time) do
      {:ok, market_data} ->
        # Validate data completeness with more lenient threshold
        case validate_data_completeness(market_data, timeframe, start_time, end_time) do
          :ok ->
            {:ok, market_data}

          {:error, reason} ->
            if retries > 0 do
              Logger.warning("Data validation failed, retrying... (#{retries} attempts left)")
              # Increased wait time between retries
              Process.sleep(2000)
              fetch_with_retries(symbol, timeframe, start_time, end_time, retries - 1)
            else
              # Even if validation fails, return partial data
              Logger.warning("Using partial data after retries exhausted: #{reason}")
              {:ok, market_data}
            end
        end

      {:error, reason} ->
        if retries > 0 do
          Logger.warning("Fetch failed, retrying... (#{retries} attempts left)")
          # Increased wait time between retries
          Process.sleep(2000)
          fetch_with_retries(symbol, timeframe, start_time, end_time, retries - 1)
        else
          {:error, reason}
        end
    end
  end

  defp validate_data_completeness(market_data, timeframe, start_time, end_time) do
    # Calculate expected number of candles based on timeframe
    expected_count = calculate_expected_candles(timeframe, start_time, end_time)
    actual_count = length(market_data)

    # Be more lenient with validation (70% of expected data is acceptable)
    if actual_count < expected_count * 0.7 do
      {:error, "Incomplete data: expected #{expected_count} candles, got #{actual_count}"}
    else
      :ok
    end
  end

  defp calculate_expected_candles(timeframe, start_time, end_time) do
    total_seconds = DateTime.diff(end_time, start_time)

    case timeframe do
      "1m" -> div(total_seconds, 60)
      "5m" -> div(total_seconds, 300)
      "15m" -> div(total_seconds, 900)
      "1h" -> div(total_seconds, 3600)
      "4h" -> div(total_seconds, 14400)
      "1d" -> div(total_seconds, 86400)
      # Default to 1h
      _ -> div(total_seconds, 3600)
    end
  end

  defp get_sync_time_range(symbol, timeframe) do
    # Query the database for the latest timestamp for this symbol/timeframe
    query =
      from m in MarketData,
        where: m.symbol == ^symbol and m.timeframe == ^timeframe,
        order_by: [desc: m.timestamp],
        limit: 1,
        select: m.timestamp

    latest_timestamp = Repo.one(query)

    # Calculate the start time for fetching (either from last record or a default)
    fetch_start_time =
      case latest_timestamp do
        nil ->
          # If no data exists, start from a reasonable past date (30 days ago)
          DateTimeConfig.add(DateTimeConfig.now(), -30, :day)

        timestamp ->
          # If data exists, start from the last timestamp we have
          # Add a timeframe-specific buffer to avoid duplicate data
          add_timeframe_buffer(timestamp, timeframe)
      end

    {fetch_start_time, DateTimeConfig.now()}
  end

  defp add_timeframe_buffer(timestamp, timeframe) do
    # Add a buffer based on the timeframe to avoid duplicate data
    {value, unit} = parse_timeframe(timeframe)
    DateTimeConfig.add(timestamp, value, unit)
  end

  defp parse_timeframe(timeframe) do
    case timeframe do
      "1m" -> {1, :minute}
      "5m" -> {5, :minute}
      "15m" -> {15, :minute}
      "1h" -> {1, :hour}
      "4h" -> {4, :hour}
      "1d" -> {1, :day}
      # Default to 1 hour if unknown
      _ -> {1, :hour}
    end
  end

  defp upsert_market_data(market_data) do
    try do
      # Get current timestamp for inserted_at
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      # Convert string price values to Decimal before insert and add timestamps
      market_data_with_decimals =
        Enum.map(market_data, fn item ->
          case item do
            # Skip nil items
            nil ->
              nil

            _ ->
              # Create a new map with all required fields
              %{
                id: Ecto.UUID.generate(),
                symbol: item.symbol,
                timeframe: item.timeframe,
                timestamp: item.timestamp,
                open: parse_decimal(item.open),
                high: parse_decimal(item.high),
                low: parse_decimal(item.low),
                close: parse_decimal(item.close),
                volume: parse_decimal(item.volume),
                source: item.source || "binance",
                inserted_at: now
              }
          end
        end)
        # Remove any nil values
        |> Enum.reject(&is_nil/1)

      # Batch insert in chunks of 1000
      total_count =
        Enum.reduce(Enum.chunk_every(market_data_with_decimals, 1000), 0, fn chunk, acc ->
          {count, _} = Repo.insert_all(MarketData, chunk, on_conflict: :nothing)
          acc + count
        end)

      {:ok, total_count}
    rescue
      e ->
        Logger.error("Error upserting market data: #{inspect(e)}")
        {:error, "Database error: #{inspect(e)}"}
    end
  end

  # Parse string or number to Decimal
  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_decimal(value) when is_number(value) do
    Decimal.new(value)
  end

  defp parse_decimal(_), do: Decimal.new(0)

  defp schedule_sync(delay) do
    Process.send_after(self(), :perform_sync, delay)
  end

  defp schedule_next_sync(state) do
    # Schedule the next sync based on the configured interval
    next_sync_time =
      DateTimeConfig.now()
      |> DateTime.add(state.sync_interval, :millisecond)
      |> DateTime.truncate(:second)
      |> DateTimeConfig.format()

    schedule_sync(state.sync_interval)

    Logger.info("Scheduled next market data sync at #{next_sync_time}")
  end

  defp count_synced_items(results) do
    # Make this function more resilient to different result formats
    Enum.reduce(results, %{total: 0, success: 0, error: 0}, fn
      # Handle the new result format with a result key
      %{result: {:ok, count}} = _item, acc ->
        %{acc | total: acc.total + count, success: acc.success + 1}

      # Handle older format where result might be {:noreply, state}
      %{result: {:noreply, _state}} = _item, acc ->
        %{acc | success: acc.success + 1}

      # Handle error result
      %{result: {:error, _}} = _item, acc ->
        %{acc | error: acc.error + 1}

      # Handle any other unexpected format (defensive programming)
      _item, acc ->
        %{acc | error: acc.error + 1}
    end)
  end
end
