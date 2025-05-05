defmodule CentralWeb.StrategyLive.Components.GeneralForm do
  use Phoenix.LiveComponent

  import CentralWeb.Components.UI.Form
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.UI.Textarea

  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4">
      <div class="mb-4">
        <h2 class="font-bold text-foreground">General Information</h2>
      </div>

      <input
        type="hidden"
        name="creation_method"
        value="form"
        phx-click="set_form_mode"
        phx-target={@myself}
      />

      <.form_item>
        <.form_label>Strategy Name</.form_label>
        <.form_control>
          <.input field={@form[:name]} placeholder="e.g. RSI + SMA Crossover Strategy" required />
        </.form_control>
        <.form_message field={@form[:name]} />
      </.form_item>

      <.form_item>
        <.form_label>Description</.form_label>
        <.form_control>
          <.textarea
            id="strategy-description"
            name={@form[:description].name}
            value={@form[:description].value}
            placeholder="Describe your strategy's logic and conditions..."
          />
        </.form_control>
        <.form_message field={@form[:description]} />
      </.form_item>
    </div>
    """
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:parent, fn -> nil end)

    {:ok, socket}
  end

  def handle_event("set_form_mode", _params, socket) do
    # Notify the parent component that form mode is being used
    if socket.assigns[:parent] do
      send(socket.assigns.parent, {:set_creation_method, "form"})
    end

    {:noreply, socket}
  end
end
