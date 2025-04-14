defmodule CentralWeb.Live.PageLive do
  use CentralWeb, :live_view

  alias CentralWeb.Components.Common.AppSidebar

  @impl true
  def mount(_params, _session, socket) do
    # Initialize theme as nil; a client-side hook likely pushes the actual theme
    {:ok, assign(socket, :theme, nil)}
  end

  @impl true
  def render(assigns) do
    # Default theme if not yet set by client hook
    assigns = Map.put_new(assigns, :theme, "light")

    ~H"""
    <AppSidebar.app_layout theme={@theme}>
      <div class="grid auto-rows-min gap-4 md:grid-cols-3">
        <div class="aspect-video rounded-xl bg-muted/50"></div>
        <div class="aspect-video rounded-xl bg-muted/50"></div>
        <div class="aspect-video rounded-xl bg-muted/50"></div>
      </div>
      <div class="min-h-[100vh] flex-1 rounded-xl bg-muted/50 md:min-h-min"></div>
    </AppSidebar.app_layout>
    """
  end

  # Handle theme change pushed from the client-side hook
  @impl true
  def handle_event("theme_changed", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, theme)}
  end
end
