defmodule Central.Repo do
  use Ecto.Repo,
    otp_app: :central,
    adapter: Ecto.Adapters.Postgres

  # Add a helper method to retrieve connection pool statistics
  def connection_stats do
    # Get all connection pool state
    state = :sys.get_state(__MODULE__)
    pool_state = state.pool_state

    # Extract connection counters
    %{
      connected: pool_state.connections |> Enum.count(),
      checked_out: pool_state.checked_out |> Enum.count(),
      idle_size: pool_state.idle_size
    }
  rescue
    # If anything fails, return default values to avoid breaking telemetry
    _e -> %{connected: 0, checked_out: 0, idle_size: 0}
  end
end
