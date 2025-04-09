defmodule CentralWeb.SystemMetrics do
  @moduledoc """
  Collects and dispatches system metrics for telemetry.
  """

  require Logger

  @doc """
  Dispatches system metrics for telemetry.
  Called periodically by the telemetry poller.
  """
  def dispatch_system_metrics do
    memory_metrics()
    process_metrics()
    application_metrics()
  end

  # Collect memory metrics
  defp memory_metrics do
    memory = :erlang.memory()

    :telemetry.execute(
      [:central, :vm, :memory],
      %{
        total: memory[:total],
        processes: memory[:processes],
        processes_used: memory[:processes_used],
        system: memory[:system],
        atom: memory[:atom],
        atom_used: memory[:atom_used],
        binary: memory[:binary],
        code: memory[:code],
        ets: memory[:ets]
      },
      %{}
    )
  end

  # Collect process metrics
  defp process_metrics do
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)

    :telemetry.execute(
      [:central, :vm, :processes],
      %{
        count: process_count,
        limit: process_limit,
        utilization: process_count / process_limit
      },
      %{}
    )
  end

  # Collect application-specific metrics
  defp application_metrics do
    # Database connection pool metrics
    try do
      # Get pool size from application config
      pool_size =
        Application.get_env(:central, Central.Repo)
        |> Keyword.get(:pool_size, 10)

      # Get connection counts directly from the Repo module
      # This is a safer approach than accessing private DBConnection functions
      stats = Central.Repo.connection_stats()

      :telemetry.execute(
        [:central, :repo, :connections],
        %{
          idle: stats.idle_size,
          checked_out: stats.checked_out,
          total: stats.connected,
          pool_size: pool_size,
          utilization: stats.checked_out / pool_size
        },
        %{}
      )
    rescue
      e ->
        Logger.debug("Failed to collect DB connection metrics: #{inspect(e)}")
    end
  end
end
