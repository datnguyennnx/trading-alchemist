defmodule CentralWeb.StrategyLive.Components.BacktestForm do
  use CentralWeb, :live_component
  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Form
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.DateTimePicker, only: [date_time_picker: 1]

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:id, fn -> "backtest-form" end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.card>
        <.card_header>
          <.card_title>Configure Backtest</.card_title>
        </.card_header>
        <.card_content>
          <.form
            :let={f}
            for={@form}
            phx-submit="run_backtest"
            phx-hook="BacktestForm"
            phx-value-start-time-id={"backtest-start-time-#{@strategy_id}"}
            phx-value-end-time-id={"backtest-end-time-#{@strategy_id}"}
            class="space-y-4"
            id={"form-#{@id}"}
          >
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.form_item>
                <.form_label>Initial Balance</.form_label>
                <.input
                  field={f[:initial_balance]}
                  name="initial_balance"
                  type="number"
                  step="0.01"
                  min="0"
                  required
                  class="h-9"
                />
              </.form_item>

              <.form_item>
                <.form_label>Position Size (%)</.form_label>
                <.input
                  field={f[:position_size]}
                  name="position_size"
                  type="number"
                  step="0.01"
                  min="0"
                  max="100"
                  required
                  class="h-9"
                />
              </.form_item>

              <.form_item>
                <.form_label>Start Time</.form_label>
                <div phx-update="ignore" id={"start_time_container_#{@strategy_id}"}>
                  <.date_time_picker
                    id={"backtest-start-time-#{@strategy_id}"}
                    name="start_time"
                    value={@start_time}
                    suppress_events={true}
                  />
                </div>
              </.form_item>

              <.form_item>
                <.form_label>End Time</.form_label>
                <div phx-update="ignore" id={"end_time_container_#{@strategy_id}"}>
                  <.date_time_picker
                    id={"backtest-end-time-#{@strategy_id}"}
                    name="end_time"
                    value={@end_time}
                    suppress_events={true}
                  />
                </div>
              </.form_item>
            </div>

            <div class="flex justify-end gap-2 pt-2">
              <.button type="submit" variant="default" phx-disable-with="Running...">
                Run Backtest
              </.button>
            </div>
          </.form>
        </.card_content>
      </.card>
    </div>
    """
  end
end
