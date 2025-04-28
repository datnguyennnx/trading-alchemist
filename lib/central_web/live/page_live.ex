defmodule CentralWeb.Live.PageLive do
  use CentralWeb, :live_view

  alias CentralWeb.Components.Common.AppSidebar

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <AppSidebar.app_layout>
      <div class="grid auto-rows-min gap-4 md:grid-cols-3">
        <div class="aspect-video rounded-xl bg-muted/50"></div>
        <div class="aspect-video rounded-xl bg-muted/50"></div>
        <div class="aspect-video rounded-xl bg-muted/50"></div>
      </div>
    </AppSidebar.app_layout>
    """
  end
end
