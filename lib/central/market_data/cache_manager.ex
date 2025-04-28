defmodule Central.MarketData.CacheManager do
  use GenServer
  require Logger

  @table_name :market_data_cache

  # --- Client API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_state) do
    Logger.info("[#{__MODULE__}] Initializing ETS table '#{@table_name}'...")
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])
    Logger.info("[#{__MODULE__}] ETS table '#{@table_name}' created successfully.")
    {:ok, %{}} # Initial state can be empty for now
  end

  @impl true
  def handle_call(:get_table_name, _from, state) do
    {:reply, @table_name, state}
  end

  # Add other handle_call/handle_cast/handle_info as needed for cache management

  @impl true
  def terminate(reason, _state) do
    Logger.info("[#{__MODULE__}] Terminating. Reason: #{inspect(reason)}")
    # ETS table is automatically destroyed when the owning process terminates
    :ok
  end
end
