defmodule CentralWeb.PageHTML do
  use CentralWeb, :html

  import Phoenix.LiveView, only: [push_event: 3]
  alias CentralWeb.Components.Common.AppSidebar

  def mount(_params, _session, socket) do
    # Get initial theme from browser using a hook
    {:ok, assign(socket, %{theme: "light"})}
  end

  def index(assigns) do
    # Make sure to include the theme in the assigns
    assigns = Map.merge(assigns, %{theme: assigns[:theme] || "light"})

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

  # Handle theme change from client-side
  def handle_event("theme-changed", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, theme: theme)}
  end

  # Handle theme change from settings dialog
  def handle_event("change_theme", %{"theme" => theme}, socket) do
    # Update the theme in socket assigns first, then push the event to JS
    {:noreply,
      socket
      |> assign(theme: theme)
      |> push_event("change_theme", %{theme: theme})
    }
  end
end
