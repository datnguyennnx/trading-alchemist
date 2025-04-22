defmodule CentralWeb.BacktestLive.Components.BacktestTest do
  @moduledoc """
  A testing module to verify the communication between backtest runner and UI components.
  This can be used for development and debugging purposes.
  """

  use CentralWeb, :live_component
  require Logger
  alias Central.Backtest.Workers.BacktestRunnerWorker
  alias Central.Backtest.Contexts.BacktestContext
  alias Phoenix.PubSub

  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Progress

  def render(assigns) do
    ~H"""
    <div>
      <.card>
        <.card_header>
          <.card_title>Backtest Communication Test</.card_title>
          <.card_description>Test the progress updates from backtest runner to UI</.card_description>
        </.card_header>

        <.card_content>
          <div class="space-y-4">
            <div class="flex justify-between">
              <div class="space-y-2">
                <h3 class="text-md font-medium">Backtest Runner Status</h3>
                <div>
                  <p class="text-sm text-muted-foreground">
                    Running backtests: <span class="font-medium">{@runner_state.running_count}</span>
                  </p>
                  <p class="text-sm text-muted-foreground">
                    Total executed:
                    <span class="font-medium">{@runner_state.metrics.total_executed}</span>
                  </p>
                  <p class="text-sm text-muted-foreground">
                    Completed: <span class="font-medium">{@runner_state.metrics.completed}</span>
                  </p>
                  <p class="text-sm text-muted-foreground">
                    Failed: <span class="font-medium">{@runner_state.metrics.failed}</span>
                  </p>
                </div>
              </div>
            </div>

            <%= if @backtest do %>
              <div class="space-y-4 border rounded-md p-4">
                <div class="flex justify-between">
                  <p class="text-sm font-medium">Backtest ID:</p>
                  <p class="text-sm">{@backtest.id}</p>
                </div>
                <div class="flex justify-between">
                  <p class="text-sm font-medium">Status:</p>
                  <p class={status_class(@backtest.status)}>
                    {String.capitalize(to_string(@backtest.status))}
                  </p>
                </div>
                <div class="flex justify-between">
                  <p class="text-sm font-medium">Progress:</p>
                  <p class="text-sm">{@progress}%</p>
                </div>

                <.progress value={@progress} class="w-full" />

                <%= if @backtest.status == :completed do %>
                  <div class="flex justify-between">
                    <p class="text-sm font-medium">Total Trades:</p>
                    <p class="text-sm">{length(@backtest.trades)}</p>
                  </div>
                  <div class="flex justify-between">
                    <p class="text-sm font-medium">Final Balance:</p>
                    <p class="text-sm">{format_balance(@backtest.final_balance)}</p>
                  </div>
                <% end %>

                <%= if @backtest.status == :failed do %>
                  <div class="flex justify-between">
                    <p class="text-sm font-medium">Error:</p>
                    <p class="text-sm text-red-500">{@backtest.metadata["error"]}</p>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="flex space-x-4">
              <.button phx-click="simulate_progress" phx-target={@myself}>
                Simulate Progress Updates
              </.button>

              <.button phx-click="check_runner_state" phx-target={@myself}>
                Refresh Runner State
              </.button>
            </div>
          </div>
        </.card_content>
      </.card>
    </div>
    """
  end

  def update(assigns, socket) do
    # Get the current state of the backtest runner
    runner_state = BacktestRunnerWorker.get_state()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:backtest, assigns[:backtest])
     |> assign(:runner_state, runner_state)
     |> assign(:progress, assigns[:progress] || 0)}
  end

  def handle_event("check_runner_state", _, socket) do
    runner_state = BacktestRunnerWorker.get_state()
    {:noreply, assign(socket, :runner_state, runner_state)}
  end

  def handle_event("simulate_progress", _, socket) do
    if socket.assigns.backtest do
      # Start a progress simulation
      backtest_id = socket.assigns.backtest.id
      Task.start(fn -> simulate_progress_updates(backtest_id) end)
      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "No backtest available to simulate")}
    end
  end

  def handle_info({:backtest_update, backtest}, socket) do
    # Extract progress from backtest metadata if it exists
    progress =
      case backtest.metadata do
        %{"progress" => progress} when is_integer(progress) -> progress
        _ -> socket.assigns.progress
      end

    {:noreply,
     socket
     |> assign(:backtest, backtest)
     |> assign(:progress, progress)}
  end

  # Simulate progress updates for testing
  defp simulate_progress_updates(backtest_id) do
    # Subscribe to updates for the UI component
    PubSub.subscribe(Central.PubSub, "backtest:#{backtest_id}")

    # Get the current backtest
    backtest = BacktestContext.get_backtest!(backtest_id)

    # Only simulate if the backtest is in pending or running state
    if backtest.status in [:pending, :running] do
      # Simulate starting the backtest
      broadcast_update(backtest_id, :running, %{progress: 0})

      # Simulate progress updates
      Enum.each(1..10, fn step ->
        # Sleep for a short time to simulate work
        :timer.sleep(500)
        progress = step * 10
        broadcast_update(backtest_id, :running, %{progress: progress})
      end)

      # Simulate completion
      :timer.sleep(500)
      broadcast_update(backtest_id, :completed, %{})
    end
  end

  # Helper function to broadcast updates
  defp broadcast_update(backtest_id, status, metadata) do
    backtest = BacktestContext.get_backtest!(backtest_id)

    # Update the backtest status
    updated_metadata = Map.merge(backtest.metadata || %{}, metadata)

    {:ok, updated_backtest} =
      backtest
      |> Ecto.Changeset.change(%{
        status: status,
        metadata: updated_metadata
      })
      |> Central.Repo.update()

    # Broadcast the update
    PubSub.broadcast(
      Central.PubSub,
      "backtest:#{backtest_id}",
      {:backtest_update, updated_backtest}
    )
  end

  defp status_class(:pending), do: "text-yellow-600"
  defp status_class(:running), do: "text-blue-600"
  defp status_class(:completed), do: "text-green-600"
  defp status_class(:failed), do: "text-red-600"
  defp status_class(_), do: "text-gray-600"

  defp format_balance(balance) when is_number(balance) do
    :erlang.float_to_binary(balance, decimals: 2)
  end

  defp format_balance(balance), do: balance
end
