defmodule Central.MarketData.MarketDataSyncWorker do
  use GenServer

  # alias Central.Repo # Removed unused
  # alias Central.Backtest.Schemas.MarketData # Removed unused
  alias Central.Backtest.Contexts.MarketDataContext
  alias Central.MarketData.Exchange.Binance.Client, as: BinanceClient
  # Add alias for your HTTP client if you have one, e.g., Tesla or Finch
  # alias Central.HttpClient

  @sync_interval_ms 5 * 60 * 1000 # 5 minutes
  @initial_sync_delay_ms 5 * 1000 # 5 seconds

  # Define symbols/timeframes to sync periodically
  # TODO: Make this dynamic based on usage or configuration
  @default_sync_symbols ["BTCUSDT"]
  @default_sync_timeframes ["1m", "5m", "15m", "1h", "4h", "1d"] # Restored full list

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    # Initial state could include API keys, base URLs, rate limiting info, etc.
    state = %{}
    # Schedule the first sync using the initial delay
    Process.send_after(self(), :sync_recent, @initial_sync_delay_ms)
    {:ok, state}
  end

  # Handle scheduled sync
  @impl true
  def handle_info(:sync_recent, state) do
    sync_recent_data()
    schedule_next_sync()
    {:noreply, state}
  end

  # Catch-all for other messages
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  # --- Private Helper Functions ---

  defp do_fetch_and_store(symbol, timeframe, start_time, end_time) do
    case fetch_binance_data(symbol, timeframe, start_time, end_time) do
      {:ok, binance_candles} ->
        market_data_changesets = transform_binance_data(symbol, timeframe, binance_candles)

        case MarketDataContext.bulk_insert_candles(market_data_changesets) do
          {:ok, _count} ->
            :ok

          # Updated error handling
          {:error, :invalid_data_structure} = error ->
            {:error, error}

          {:error, reason} -> # Catch other potential errors
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Use the actual Binance Client to fetch data
  defp fetch_binance_data(symbol, timeframe, start_time, end_time) do
    BinanceClient.download_historical_data(symbol, timeframe, start_time, end_time, 1000)
    # The client already handles basic error logging, so we just return the result
  end

  # Transform the maps returned by BinanceClient into maps suitable for insert_all
  defp transform_binance_data(_symbol, _timeframe, binance_candle_maps) when is_list(binance_candle_maps) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second) # REVERTING to NaiveDateTime
    Enum.map(binance_candle_maps, fn candle_map ->
      # The BinanceClient already parsed the data into a map with correct keys
      # We just need to ensure data types are compatible if necessary (client seems to handle decimals)
      # Ensure timestamp is truncated (client also does this, but belt-and-suspenders)
      attrs = Map.update(candle_map, :timestamp, nil, fn ts -> DateTime.truncate(ts, :second) end)

      # Convert string prices/volumes from client map to Decimals if they aren't already
      # (Assuming client returns them as strings as per API standard)
      attrs =
        attrs
        |> Map.update!(:open, &Decimal.new/1)
        |> Map.update!(:high, &Decimal.new/1)
        |> Map.update!(:low, &Decimal.new/1)
        |> Map.update!(:close, &Decimal.new/1)
        |> Map.update!(:volume, &Decimal.new/1)

      # Add timestamps manually for insert_all
      attrs = Map.put(attrs, :inserted_at, now)

      # Return the attributes map directly
      attrs # Ensure this is the last expression
      # MarketData.changeset(%MarketData{}, attrs) <-- No longer create changeset here
    end)
  end

  # --- Periodic Sync Logic ---

  defp schedule_next_sync do
    Process.send_after(self(), :sync_recent, @sync_interval_ms)
  end

  defp sync_recent_data do
    end_time = DateTime.utc_now() |> DateTime.truncate(:second)

    for symbol <- @default_sync_symbols, timeframe <- @default_sync_timeframes do
      # Calculate a reasonable start time based on timeframe
      # Fetches slightly more than needed to handle potential gaps or delays
      start_time = calculate_recent_start_time(end_time, timeframe)
      # Use do_fetch_and_store, which handles fetching and saving
      do_fetch_and_store(symbol, timeframe, start_time, end_time)
      # TODO: Add a small delay between requests? Binance might rate limit.
      Process.sleep(500) # Small delay between symbol/timeframe fetches
    end
  end

  # Calculate how far back to fetch for periodic sync based on timeframe
  defp calculate_recent_start_time(end_time, timeframe) do
    seconds_back = case timeframe do
      "1m" -> 15 * 60        # Last 15 mins for 1m
      "5m" -> 60 * 60        # Last 1 hour for 5m
      "15m" -> 3 * 60 * 60   # Last 3 hours for 15m
      "1h" -> 12 * 60 * 60  # Last 12 hours for 1h
      "4h" -> 2 * 24 * 60 * 60 # Last 2 days for 4h
      "1d" -> 7 * 24 * 60 * 60 # Last 7 days for 1d
      _ -> 60 * 60           # Default to 1 hour
    end

    DateTime.add(end_time, -seconds_back, :second)
  end
end
