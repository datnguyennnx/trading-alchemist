defmodule Central.Backtest.Workers.BacktestRunner do
  @moduledoc """
  Background worker for executing backtests asynchronously.

  Handles queueing, execution, and monitoring of backtest jobs with:
  - Rate limiting to prevent system overload
  - Automatic recovery of interrupted backtests
  - Progress tracking and real-time UI updates
  - Error handling and comprehensive logging
  """

  use GenServer
  require Logger

  alias Central.Backtest.Services.{StrategyExecutor, Performance, RiskManager}
  alias Central.Backtest.Schemas.Backtest
  alias Central.Repo
  alias Central.Config.DateTimeConfig

  # Configuration constants
  @max_concurrent_backtests 5
  @backtest_timeout 300_000  # 5 minutes
  @retry_delay 5_000         # 5 seconds between retries

  @doc """
  Starts the backtest runner worker.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Initializes the worker state with monitoring capabilities.
  """
  def init(_args) do
    # Recover any pending backtests on restart
    recover_pending_backtests()
    {:ok, %{
      running: %{},
      metrics: %{
        total_executed: 0,
        failed: 0,
        completed: 0,
        canceled: 0
      },
      progress: %{}
    }}
  end

  @doc """
  Queues a backtest for async execution with rate limiting.

  ## Parameters
    - args: Map containing :backtest_id and optional parameters
  """
  def perform_async(%{"backtest_id" => _backtest_id} = args) do
    GenServer.cast(__MODULE__, {:execute_backtest, args})
  end

  @doc """
  Gets the current runner state for monitoring purposes.

  ## Returns
    - Map with running count, metrics, and progress info
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Updates the progress of a running backtest.

  ## Parameters
    - backtest_id: ID of the backtest
    - progress: Integer progress value (0-100)
  """
  def update_progress(backtest_id, progress) when is_integer(progress) and progress >= 0 and progress <= 100 do
    GenServer.cast(__MODULE__, {:update_progress, backtest_id, progress})
  end

  @doc """
  Cancels a running backtest.

  ## Parameters
    - backtest_id: ID of the backtest to cancel
  """
  def cancel_backtest(backtest_id) do
    GenServer.cast(__MODULE__, {:cancel_backtest, backtest_id})
  end

  def handle_call(:get_state, _from, state) do
    # Return a safe copy of the state (without sensitive data)
    safe_state = %{
      running_count: map_size(state.running),
      metrics: state.metrics,
      progress: state.progress
    }
    {:reply, safe_state, state}
  end

  def handle_cast({:update_progress, backtest_id, progress}, state) do
    # Update the progress in the state
    state = put_in(state, [:progress, backtest_id], progress)

    # Broadcast progress to UI
    broadcast_progress(backtest_id, :running, %{progress: progress})

    {:noreply, state}
  end

  def handle_cast({:execute_backtest, %{"backtest_id" => backtest_id} = args}, state) do
    # Check if we've reached the maximum concurrent backtests
    cond do
      # Check if this backtest is already running
      Map.has_key?(state.running, backtest_id) ->
        Logger.warning("Backtest #{backtest_id} is already running")
        {:noreply, state}

      # Check concurrent limit
      map_size(state.running) >= @max_concurrent_backtests ->
        Logger.warning("Backtest queue full, deferring execution of backtest: #{backtest_id}")
        Process.send_after(self(), {:retry_backtest, args}, @retry_delay)
        {:noreply, state}

      # We can run the backtest
      true ->
        # Mark as running in the worker state and initialize progress tracking
        state = state
                |> put_in([:running, backtest_id], %{
                  started_at: DateTime.utc_now(),
                  task_ref: nil
                })
                |> put_in([:progress, backtest_id], 0)

        # Update the backtest status in the database
        update_status(backtest_id, :running)

        # Execute the backtest in a supervised Task
        task = Task.Supervisor.async_nolink(Central.TaskSupervisor, fn ->
          execute_backtest_with_timeout(backtest_id)
        end)

        # Store task reference
        state = put_in(state, [:running, backtest_id, :task_ref], task.ref)

        {:noreply, state}
    end
  end

  def handle_cast({:cancel_backtest, backtest_id}, state) do
    # Check if the backtest is running
    case get_in(state, [:running, backtest_id]) do
      nil ->
        # Not running, nothing to do
        {:noreply, state}

      %{task_ref: ref} when is_reference(ref) ->
        # Find the PID associated with the task
        case Process.info(self(), :links) do
          {:links, links} ->
            # Find the process linked to this task
            task_pid = Enum.find(links, fn pid ->
              Process.info(pid, :dictionary)
              |> case do
                {:dictionary, dict} -> dict[:"$initial_call"] == {Task.Supervised, :invoke, 3}
                _ -> false
              end
            end)

            if task_pid, do: Process.exit(task_pid, :kill)
        end

        # Update status
        update_status(backtest_id, :canceled, %{
          canceled_at: DateTimeConfig.format(DateTime.utc_now()),
          canceled_reason: "User requested cancellation"
        })

        # Update metrics
        state = update_in(state.metrics, fn metrics ->
          metrics
          |> Map.update!(:total_executed, &(&1 + 1))
          |> Map.update!(:canceled, &(&1 + 1))
        end)

        # Remove from running and progress tracking
        {_, state} = pop_in(state, [:running, backtest_id])
        {_, state} = pop_in(state, [:progress, backtest_id])

        Logger.info("Backtest #{backtest_id} was canceled")

        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    # Find the backtest associated with this task
    case Enum.find(state.running, fn {_id, data} -> data.task_ref == ref end) do
      {backtest_id, _} ->
        handle_backtest_completion(backtest_id, reason, state)
      nil ->
        {:noreply, state}
    end
  end

  def handle_info({ref, result}, state) when is_reference(ref) do
    # Handle normal task completion
    # The task completed successfully with the given result

    # We don't care about the DOWN message now, so let's demonitor and flush it
    Process.demonitor(ref, [:flush])

    # Find the backtest associated with this task reference
    case Enum.find(state.running, fn {_id, data} -> data.task_ref == ref end) do
      {backtest_id, _} ->
        # Update the state based on the result
        case result do
          {:ok, _} ->
            # Successful completion
            handle_backtest_completion(backtest_id, :normal, state)
          {:error, error} ->
            # Task completed but with an error
            Logger.error("Backtest error: #{inspect(error)}")
            {:noreply, state} = handle_backtest_completion(backtest_id, {:error, error}, state)
            {:noreply, state}
        end
      nil ->
        # No backtest found for this reference - unusual but handle gracefully
        {:noreply, state}
    end
  end

  def handle_info({:retry_backtest, args}, state) do
    handle_cast({:execute_backtest, args}, state)
  end

  defp execute_backtest_with_timeout(backtest_id) do
    try do
      # Execute the backtest with progress tracking and apply timeout
      task = Task.async(fn ->
        StrategyExecutor.execute_backtest(backtest_id, fn progress ->
          # Update progress in the runner state
          update_progress(backtest_id, progress)
        end)
      end)

      # Apply timeout
      case Task.yield(task, @backtest_timeout) || Task.shutdown(task) do
        {:ok, result} ->
          # Task completed successfully within timeout
          result
        nil ->
          # Task took too long and was shut down
          {:error, :timeout}
      end
    rescue
      error ->
        Logger.error("Backtest error: #{inspect(error)}\n#{Exception.format_stacktrace()}")
        {:error, error}
    catch
      kind, reason ->
        Logger.error("Backtest caught #{kind}: #{inspect(reason)}\n#{Exception.format_stacktrace()}")
        {:error, {kind, reason}}
    end
  end

  defp handle_backtest_completion(backtest_id, reason, state) do
    # Remove from running state
    {_, new_state} = pop_in(state, [:running, backtest_id])
    # Remove from progress tracking
    {_, new_state} = pop_in(new_state, [:progress, backtest_id])

    # Update metrics
    new_state = update_in(new_state.metrics, fn metrics ->
      metrics
      |> Map.update!(:total_executed, &(&1 + 1))
      |> case do
        metrics when reason == :normal ->
          Map.update!(metrics, :completed, &(&1 + 1))
        metrics ->
          Map.update!(metrics, :failed, &(&1 + 1))
      end
    end)

    case reason do
      :normal ->
        # Update status, generate performance metrics, and notify completion
        update_status(backtest_id, :completed)

        # Generate performance summary and update risk metrics
        Task.start(fn ->
          try do
            # Run performance calculations in parallel with error trapping
            task1 = Task.async(fn ->
              try do
                Performance.generate_performance_summary(backtest_id)
              rescue
                e ->
                  Logger.error("Performance summary error: #{inspect(e)}")
                  Logger.error("Performance summary stacktrace: #{Exception.format_stacktrace()}")
                  # Return to avoid crashing the task
                  {:error, e}
              end
            end)

            task2 = Task.async(fn ->
              try do
                RiskManager.update_risk_metrics(backtest_id)
              rescue
                e ->
                  Logger.error("Risk metrics error: #{inspect(e)}")
                  Logger.error("Risk metrics stacktrace: #{Exception.format_stacktrace()}")
                  # Return to avoid crashing the task
                  {:error, e}
              end
            end)

            # Wait for both tasks to complete with timeout
            Task.await(task1, 30_000)
            Task.await(task2, 30_000)
          rescue
            e -> Logger.error("Error generating performance metrics: #{inspect(e)}")
          end
        end)

        notify_completion(backtest_id)
        Logger.info("Backtest completed successfully: #{backtest_id}")

      {:error, error} ->
        # Handle error case with detailed error info
        error_message = case error do
          %{__exception__: true} = exception -> Exception.message(exception)
          :timeout -> "Backtest timed out after #{@backtest_timeout}ms"
          _ -> inspect(error)
        end
        update_status(backtest_id, :failed, %{error: error_message})
        Logger.error("Backtest failed: #{backtest_id}, reason: #{error_message}")

      _ ->
        # Generic failure case
        update_status(backtest_id, :failed, %{error: inspect(reason)})
        Logger.error("Backtest failed: #{backtest_id}, reason: #{inspect(reason)}")
    end

    {:noreply, new_state}
  end

  defp update_status(backtest_id, status, additional_metadata \\ %{}) do
    backtest = Repo.get!(Backtest, backtest_id)

    # Merge existing metadata with new values
    updated_metadata = Map.merge(backtest.metadata || %{}, additional_metadata)

    # Add status change timestamp
    status_timestamp = %{
      "#{status}_at" => DateTimeConfig.format(DateTime.utc_now())
    }

    # Update backtest
    backtest
    |> Ecto.Changeset.change(%{
      status: status,
      metadata: Map.merge(updated_metadata, status_timestamp)
    })
    |> Repo.update!()
  end


  defp recover_pending_backtests do
    import Ecto.Query

    # Find all pending or running backtests that need to be restarted
    query = from b in Backtest,
      where: b.status in [:pending, :running]

    pending_backtests = Repo.all(query)

    Logger.info("Recovering #{length(pending_backtests)} pending backtests")

    # Mark all as pending
    Enum.each(pending_backtests, fn backtest ->
      update_status(backtest.id, :pending, %{recovered: true})

      # Requeue the backtest
      perform_async(%{"backtest_id" => backtest.id})
    end)
  end

  defp notify_completion(backtest_id) do
    # Fetch the completed backtest with associations
    backtest =
      Repo.get!(Backtest, backtest_id)
      |> Repo.preload([:strategy, :trades, :performance_summary])

    # Broadcast to subscribers
    Phoenix.PubSub.broadcast(
      Central.PubSub,
      "backtest:#{backtest_id}",
      {:backtest_update, backtest}
    )
  end

  # Broadcasts intermediate progress updates to the UI
  defp broadcast_progress(backtest_id, status, metadata \\ %{}) do
    # Get the current backtest
    backtest = Repo.get!(Backtest, backtest_id)

    # Update metadata with timestamps
    now = DateTime.utc_now()
    status_metadata = Map.merge(metadata, %{
      "#{status}_at" => DateTimeConfig.format(now),
      "last_update" => DateTimeConfig.format(now)
    })

    # Merge with existing metadata
    updated_metadata = Map.merge(backtest.metadata || %{}, status_metadata)

    # Update the backtest with new status and metadata
    {:ok, updated_backtest} =
      backtest
      |> Ecto.Changeset.change(%{
        status: status,
        metadata: updated_metadata
      })
      |> Repo.update()

    # Send progress update to UI
    backtest_with_assocs = Repo.preload(updated_backtest, [:strategy, :trades])
    Phoenix.PubSub.broadcast(
      Central.PubSub,
      "backtest:#{backtest_id}",
      {:backtest_update, backtest_with_assocs}
    )
  end
end
