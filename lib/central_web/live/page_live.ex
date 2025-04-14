defmodule CentralWeb.Live.PageLive do
  use CentralWeb, :live_view

  alias CentralWeb.Components.Common.AppSidebar

  @impl true
  def mount(_params, _session, socket) do
    # Initialize with a default theme
    {:ok, assign(socket, :theme, "light")}
  end

  @impl true
  def render(assigns) do
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

  @impl true
  def handle_event("theme_changed", %{"theme" => theme}, socket) do
    # Only update if theme has changed
    if theme != socket.assigns.theme do
      {:noreply, assign(socket, :theme, theme)}
    else
      {:noreply, socket}
    end
  end
end
