defmodule Central.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  # Add alias
  alias Central.MarketData.CacheManager

  @impl true
  def start(_type, _args) do
    children = [
      CentralWeb.Telemetry,
      Central.Repo,
      {DNSCluster, query: Application.get_env(:central, :dns_cluster_query) || :ignore},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Central.Finch},
      # Registry for named processes (like WebSocket streams)
      {Registry, keys: :unique, name: Central.Registry},
      # Add Phoenix PubSub
      {Phoenix.PubSub, name: Central.PubSub},
      # Task Supervisor for background jobs
      {Task.Supervisor, name: Central.TaskSupervisor},
      # Start the Market Data Cache Manager (owns the ETS table)
      CacheManager,
      # Start the BacktestRunner GenServer
      {Central.Backtest.Workers.BacktestRunnerWorker, []},
      # Start to serve requests, typically the last entry
      CentralWeb.Endpoint,
      TwMerge.Cache,
      # Start the MarketData Sync Worker (periodic sync) - AFTER CacheManager
      Central.MarketData.MarketDataSyncWorker,
      # Start the MarketData History Fetcher (on-demand) - AFTER CacheManager
      Central.MarketData.MarketDataHistoryFetcher
      # Add other workers and supervisors as needed
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Central.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CentralWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
