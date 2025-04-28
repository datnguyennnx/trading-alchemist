defmodule Central.MarketData.MarketDataHistoryFetcher do
  use GenServer
  require Logger

  # alias Central.Repo # Removed unused
  # alias Central.Backtest.Schemas.MarketData # Removed unused
  alias Central.Backtest.Contexts.MarketDataContext
  alias Central.MarketData.Exchange.Binance.Client, as: BinanceClient

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Asynchronously triggers fetching and storing of historical market data for a given range.
  """
  def fetch_range(symbol, timeframe, start_time, end_time) do
    # Add basic validation or guards?
    if is_binary(symbol) and is_binary(timeframe) and
         is_struct(start_time, DateTime) and is_struct(end_time, DateTime) and
         DateTime.compare(end_time, start_time) == :gt do
      GenServer.cast(__MODULE__, {:fetch_range, symbol, timeframe, start_time, end_time})
      :ok
    else
      Logger.error(
        "Invalid arguments passed to MarketDataHistoryFetcher.fetch_range: #{inspect({symbol, timeframe, start_time, end_time})}"
      )

      {:error, :invalid_arguments}
    end
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    Logger.info("[MarketDataHistoryFetcher] Started")
    state = %{}
    {:ok, state}
  end

  @impl true
  def handle_cast({:fetch_range, symbol, timeframe, start_time, end_time}, state) do
    IO.puts(
      "[MarketDataHistoryFetcher] Handling :fetch_range: #{symbol} #{timeframe} #{inspect(start_time)} -> #{inspect(end_time)}"
    )

    # Trigger the actual fetching logic
    do_fetch_and_store(symbol, timeframe, start_time, end_time)
    {:noreply, state}
  end

  # Catch-all for other messages
  @impl true
  def handle_info(msg, state) do
    Logger.debug("[MarketDataHistoryFetcher] Received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("[MarketDataHistoryFetcher] Terminating: #{inspect(reason)}")
    :ok
  end

  # --- Private Helper Functions ---

  # This function is now only used by the history fetcher
  defp do_fetch_and_store(symbol, timeframe, start_time, end_time) do
    # 1. Fetch data from Binance API
    IO.puts("[MarketDataHistoryFetcher] Fetching Binance data...")

    case fetch_binance_data(symbol, timeframe, start_time, end_time) do
      {:ok, binance_candles} ->
        IO.puts(
          "[MarketDataHistoryFetcher] Fetched #{length(binance_candles)} candles from Binance."
        )

        if Enum.empty?(binance_candles) do
          IO.puts(
            "[MarketDataHistoryFetcher] No candles returned from Binance for range, nothing to store."
          )

          # Nothing more to do
          :ok
        else
          # 2. Transform data to MarketData schema format
          market_data_changesets = transform_binance_data(symbol, timeframe, binance_candles)

          IO.puts(
            "[MarketDataHistoryFetcher] Transformed #{length(market_data_changesets)} changesets."
          )

          # 3. Store data in the database
          IO.puts("[MarketDataHistoryFetcher] Storing data in DB...")

          case MarketDataContext.bulk_insert_candles(market_data_changesets) do
            {:ok, count} ->
              Logger.info("Successfully stored #{count} candles for #{symbol} #{timeframe}")
              IO.puts("[MarketDataHistoryFetcher] Stored #{count} candles successfully.")
              # Broadcast that new data is available for this range
              broadcast_update(symbol, timeframe, start_time, end_time)

            # Updated error handling
            {:error, :invalid_data_structure} = error ->
              Logger.error(
                "Failed to store candles (invalid data structure) for #{symbol} #{timeframe}"
              )

              IO.puts("[MarketDataHistoryFetcher] Failed to store candles: #{inspect(error)}")

            # Catch other potential errors
            {:error, reason} ->
              Logger.error(
                "Failed to store candles for #{symbol} #{timeframe}: #{inspect(reason)}"
              )

              IO.puts("[MarketDataHistoryFetcher] Failed to store candles: #{inspect(reason)}")
          end
        end

      {:error, reason} ->
        Logger.error(
          "Failed to fetch data from Binance for #{symbol} #{timeframe}: #{inspect(reason)}"
        )

        IO.puts("[MarketDataHistoryFetcher] Failed to fetch from Binance: #{inspect(reason)}")
    end
  end

  # Use the actual Binance Client to fetch data
  defp fetch_binance_data(symbol, timeframe, start_time, end_time) do
    Logger.info(
      "Fetching Binance data for #{symbol} #{timeframe} from #{start_time} to #{end_time}"
    )

    # Use limit: 1000 as per Binance API max
    # The caller (if necessary) should handle chunking for requests > 1000 candles
    BinanceClient.download_historical_data(symbol, timeframe, start_time, end_time, 1000)
    # The client already handles basic error logging, so we just return the result
  end

  # Transform the maps returned by BinanceClient into maps suitable for insert_all
  defp transform_binance_data(_symbol, _timeframe, binance_candle_maps)
       when is_list(binance_candle_maps) do
    # REVERTING to NaiveDateTime
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Enum.map(binance_candle_maps, fn candle_map ->
      attrs = Map.update(candle_map, :timestamp, nil, fn ts -> DateTime.truncate(ts, :second) end)

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
      attrs
    end)
  end

  defp broadcast_update(symbol, timeframe, start_time, end_time) do
    topic = "market_data_updated:#{symbol}:#{timeframe}"
    payload = %{start_time: start_time, end_time: end_time}

    IO.puts(
      "[MarketDataHistoryFetcher] Broadcasting update on topic '#{topic}' with payload: #{inspect(payload)}"
    )

    Phoenix.PubSub.broadcast(Central.PubSub, topic, {:range_updated, payload})
  end
end
