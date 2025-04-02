defmodule Central.MarketData.Server do
  use GenServer
  alias Phoenix.PubSub

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Start with some base values
    initial_state = Map.merge(state, %{
      last_price: 100.0,
      last_time: DateTime.utc_now() |> DateTime.to_unix()
    })

    # Start the periodic data fetch
    schedule_data_fetch()
    {:ok, initial_state}
  end

  def handle_info(:fetch_data, state) do
    # Generate a new candlestick
    new_data = generate_next_candlestick(state)

    # Update the state with the latest values
    updated_state = %{
      last_price: new_data.close,
      last_time: new_data.time
    }

    # Broadcast the new data to all subscribers
    PubSub.broadcast(Central.PubSub, "market_data", {:update_chart, new_data})

    # Schedule the next fetch
    schedule_data_fetch()

    {:noreply, updated_state}
  end

  defp schedule_data_fetch do
    # Fetch data every 5 seconds
    Process.send_after(self(), :fetch_data, 5000)
  end

  defp generate_next_candlestick(state) do
    # Use the last price as a base for the next candlestick
    last_price = state.last_price

    # Add some random movement
    price_change = :rand.normal(0, 1) * (last_price * 0.01)
    open = last_price
    close = last_price + price_change

    # Add some volatility
    high = max(open, close) + :rand.uniform() * (last_price * 0.005)
    low = min(open, close) - :rand.uniform() * (last_price * 0.005)

    # Increment the time (in seconds)
    new_time = state.last_time + 60

    # Return the new candlestick
    %{
      time: new_time,
      open: Float.round(open, 2),
      high: Float.round(high, 2),
      low: Float.round(low, 2),
      close: Float.round(close, 2)
    }
  end
end
