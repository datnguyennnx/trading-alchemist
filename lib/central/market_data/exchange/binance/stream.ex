defmodule Central.MarketData.Exchange.Binance.Stream do
  @moduledoc """
  Handles WebSocket connections to Binance for real-time data streams.
  Manages connection lifecycle, subscription, and broadcasting of data.
  """

  use GenServer
  require Logger

  @stream_url "wss://ws-api.binance.com:443/ws-api/v3"
  @reconnect_backoff [100, 500, 1_000, 2_000, 5_000]

  # API

  @doc """
  Starts a stream GenServer for a specific symbol.
  """
  def start_link(symbol) do
    GenServer.start_link(__MODULE__, symbol, name: via_tuple(symbol))
  end

  @doc """
  Subscribes to updates for a specific symbol.
  Returns the current subscribers after adding the new one.

  ## Options
    - pid: The process ID to receive messages (defaults to caller)
  """
  def subscribe(symbol, opts \\ []) do
    pid = Keyword.get(opts, :pid, self())

    case get_pid(symbol) do
      nil ->
        {:error, :stream_not_running}

      pid_stream ->
        GenServer.call(pid_stream, {:subscribe, pid})
    end
  end

  @doc """
  Unsubscribes from updates for a specific symbol.
  Returns the current subscribers after removing the specified one.

  ## Options
    - pid: The process ID to unsubscribe (defaults to caller)
  """
  def unsubscribe(symbol, opts \\ []) do
    pid = Keyword.get(opts, :pid, self())

    case get_pid(symbol) do
      nil ->
        {:error, :stream_not_running}

      pid_stream ->
        GenServer.call(pid_stream, {:unsubscribe, pid})
    end
  end

  @doc """
  Gets the current state of the stream for a symbol.
  """
  def get_state(symbol) do
    case get_pid(symbol) do
      nil ->
        {:error, :stream_not_running}

      pid ->
        GenServer.call(pid, :get_state)
    end
  end

  # CALLBACKS

  @impl GenServer
  def init(symbol) do
    Logger.info("Starting Binance stream for #{symbol}")
    symbol = String.downcase(symbol)

    # Schedule connection setup for the next event loop iteration
    # This allows the GenServer to complete initialization quickly
    send(self(), :connect)

    {:ok,
     %{
       symbol: symbol,
       connection: nil,
       # Default to 1m candles
       socket_url: "#{@stream_url}/#{symbol}@kline_1m",
       subscribers: MapSet.new(),
       connection_attempts: 0,
       connected: false,
       backoff_index: 0,
       last_message_at: nil
     }}
  end

  @impl GenServer
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    new_subscribers = MapSet.put(state.subscribers, pid)
    {:reply, {:ok, MapSet.size(new_subscribers)}, %{state | subscribers: new_subscribers}}
  end

  @impl GenServer
  def handle_call({:unsubscribe, pid}, _from, state) do
    new_subscribers = MapSet.delete(state.subscribers, pid)
    {:reply, {:ok, MapSet.size(new_subscribers)}, %{state | subscribers: new_subscribers}}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    # Don't expose socket details
    sanitized_state = Map.drop(state, [:connection])
    {:reply, {:ok, sanitized_state}, state}
  end

  @impl GenServer
  def handle_info(:connect, state) do
    # This would be implemented with a proper WebSocket client
    # For now, let's simulate it with a placeholder

    # Pseudo-code for WebSocket connection
    # {:ok, conn} = WebSocketClient.connect(state.socket_url)

    # Instead, we'll just simulate a successful connection
    # In a real implementation, you'd use WebSockex or a similar library
    Logger.info("Connected to Binance WebSocket for #{state.symbol}")

    # Schedule heartbeat to monitor connection health
    schedule_heartbeat()

    {:noreply,
     %{
       state
       | connection: :simulated_connection,
         connected: true,
         connection_attempts: 0,
         backoff_index: 0,
         last_message_at: DateTime.utc_now()
     }}
  end

  @impl GenServer
  def handle_info(:heartbeat, state) do
    # Check if we've received a message recently
    now = DateTime.utc_now()

    no_message_duration =
      case state.last_message_at do
        nil -> 0
        last -> DateTime.diff(now, last, :second)
      end

    # If no message for more than 60 seconds, reconnect
    if no_message_duration > 60 do
      Logger.warning(
        "No messages received for #{no_message_duration} seconds, reconnecting to #{state.symbol} stream"
      )

      send(self(), :reconnect)
      {:noreply, state}
    else
      # Connection seems healthy, schedule next heartbeat
      schedule_heartbeat()
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:reconnect, state) do
    # Close existing connection
    # In a real implementation, you'd close the WebSocket
    # WebSocketClient.close(state.connection)

    backoff_ms = get_backoff_time(state.backoff_index)

    Logger.info(
      "Reconnecting to #{state.symbol} stream in #{backoff_ms}ms (attempt #{state.connection_attempts + 1})"
    )

    # Schedule reconnection after backoff
    Process.send_after(self(), :connect, backoff_ms)

    {:noreply,
     %{
       state
       | connection: nil,
         connected: false,
         connection_attempts: state.connection_attempts + 1,
         backoff_index: min(state.backoff_index + 1, length(@reconnect_backoff) - 1)
     }}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Subscriber process terminated, remove from subscribers
    new_subscribers = MapSet.delete(state.subscribers, pid)

    # If no more subscribers and not a permanent stream, terminate
    if MapSet.size(new_subscribers) == 0 do
      Logger.info("No more subscribers for #{state.symbol} stream, terminating")
      {:stop, :normal, %{state | subscribers: new_subscribers}}
    else
      {:noreply, %{state | subscribers: new_subscribers}}
    end
  end

  # Simulated message handling - in a real implementation, this would
  # be triggered by WebSocket messages from Binance
  @impl GenServer
  def handle_info({:websocket_message, data}, state) do
    # Process the message and broadcast to subscribers
    try do
      processed_data = process_kline_data(data)
      broadcast_to_subscribers(state.subscribers, {:kline_update, state.symbol, processed_data})

      {:noreply, %{state | last_message_at: DateTime.utc_now()}}
    rescue
      e ->
        Logger.error("Error processing WebSocket message: #{inspect(e)}")
        {:noreply, state}
    end
  end

  # PRIVATE FUNCTIONS

  defp via_tuple(symbol) do
    {:via, Registry, {Central.Registry, {__MODULE__, String.downcase(symbol)}}}
  end

  defp get_pid(symbol) do
    case Registry.lookup(Central.Registry, {__MODULE__, String.downcase(symbol)}) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  defp schedule_heartbeat do
    # Check every 30 seconds
    Process.send_after(self(), :heartbeat, 30_000)
  end

  defp get_backoff_time(index) do
    Enum.at(@reconnect_backoff, index)
  end

  defp process_kline_data(data) do
    # Process raw WebSocket data into a structured format
    # This is a simplified example - actual implementation would parse JSON
    # and potentially use Binance.Client.parse_kline or similar logic
    # Placeholder
    %{raw: data}
  end

  defp broadcast_to_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      send(pid, message)
    end)
  end
end
