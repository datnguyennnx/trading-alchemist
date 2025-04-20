defmodule CentralWeb.StrategyLive.Components.StrategyModeSelector do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4 mb-8">
      <h2 class="font-bold text-foreground">Choose Input Method</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <!-- Form Mode Card -->
        <div
          class={"bg-card rounded-md p-4 cursor-pointer border transition-all duration-200
            #{if @current_mode == "form",
               do: "border-primary/70 ring-2 ring-offset-4 ring-primary/50 bg-accent/20",
               else: "border-input hover:border-input/80 hover:bg-accent/10"}"}
          phx-click="set_creation_mode"
          phx-value-mode="form"
        >
          <div class="flex flex-col space-y-2">
            <h3 class="text-base font-medium">Form Mode</h3>
            <p class="text-sm text-muted-foreground">
              Use a structured form interface with dedicated fields for each parameter.
              Perfect for most users.
            </p>
          </div>
        </div>

        <!-- JSON Mode Card -->
        <div
          class={"bg-card rounded-md p-4 cursor-pointer border transition-all duration-200
            #{if @current_mode == "json",
               do: "border-primary/70 ring-2 ring-offset-4 ring-primary/50 bg-accent/20",
               else: "border-input hover:border-input/80 hover:bg-accent/10"}"}
          phx-click="set_creation_mode"
          phx-value-mode="json"
        >
          <div class="flex flex-col space-y-2">
            <h3 class="text-base font-medium">JSON Mode</h3>
            <p class="text-sm text-muted-foreground">
              Advanced: Edit the complete strategy JSON directly.
              For developers and power users.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end
