defmodule CentralWeb.Components.Common.SettingsDialog do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  # Import the SaladUI components
  import SaladUI.Button, only: [button: 1]
  import SaladUI.Dialog, only: [dialog: 1, dialog_header: 1]

  import SaladUI.DropdownMenu,
    only: [dropdown_menu: 1, dropdown_menu_trigger: 1, dropdown_menu_content: 1]

  import SaladUI.Menu, only: [menu: 1, menu_group: 1, menu_item: 1]
  import SaladUI.Icon, only: [icon: 1]

  # Define the settings navigation items
  @settings_nav_items [
    %{
      title: "General",
      icon: "cog-6-tooth",
      is_active: true
    }
  ]

  attr :id, :string, default: "settings-dialog"
  attr :trigger_id, :string, default: nil
  attr :class, :string, default: nil
  attr :current_theme, :string, default: "light"
  attr :settings_nav_items, :list, default: @settings_nav_items

  def settings_dialog(assigns) do
    ~H"""
    <div>
      <.dialog id={@id} class="sm:max-w-[880px] p-0 flex gap-0 bg-background text-foreground">
        <div class="flex flex-row w-full">
          <!-- Settings Sidebar -->
          <div class="flex w-[200px] flex-col gap-4 border-r border-border text-sidebar-foreground p-4 overflow-hidden">
            <.dialog_header class="px-2">
              <div class="text-foreground font-medium">Settings</div>
            </.dialog_header>
            <div class="h-[500px] overflow-y-auto">
              <div class="flex flex-col gap-1">
                <%= for item <- @settings_nav_items do %>
                  <.settings_nav_item item={item} />
                <% end %>
              </div>
            </div>
          </div>

          <!-- Settings Content -->
          <div class="m-4 flex-1 p-6 bg-background text-foreground">
            <div class="flex flex-col gap-6">
              <div class="flex flex-col gap-2">
                <div class="flex items-center justify-between">
                  <div class="flex flex-col gap-1">
                    <h3 class="text-sm font-medium">WebUI Settings</h3>
                    <p class="text-sm text-muted-foreground">Theme</p>
                  </div>
                  <.theme_selector current_theme={@current_theme} />
                </div>
              </div>
            </div>
          </div>
        </div>
      </.dialog>
    </div>
    """
  end

  # Navigation item component
  attr :item, :map, required: true
  defp settings_nav_item(assigns) do
    ~H"""
    <.button
      variant="ghost"
      class={"justify-start gap-2 text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground #{if @item.is_active, do: "bg-sidebar-accent text-sidebar-accent-foreground"}"}
    >
      <span class="h-4 w-4 flex items-center">
        <.icon name={"hero-#{@item.icon}"} class="h-4 w-4" />
      </span>
      <span><%= @item.title %></span>
    </.button>
    """
  end

  # Theme selector component
  attr :current_theme, :string, required: true
  def theme_selector(assigns) do
    ~H"""
    <div id="theme-selector" phx-hook="ThemeUIUpdater">
      <.dropdown_menu>
        <.dropdown_menu_trigger>
          <div id="theme-dropdown-container" phx-update="ignore">
            <.button
              variant="outline"
              size="sm"
              class="flex items-center gap-2 bg-background border-border text-foreground hover:bg-accent hover:text-accent-foreground"
              id="theme-dropdown-trigger"
            >
              <span class="h-4 w-4 flex items-center theme-icon">
                <.icon name={"hero-#{if @current_theme == "light", do: "sun", else: "moon"}"} class="h-4 w-4" />
              </span>
              <span class="theme-text"><%= if @current_theme == "light", do: "Light", else: "Dark" %></span>
            </.button>
          </div>
        </.dropdown_menu_trigger>
        <.dropdown_menu_content align="end" class="bg-popover text-popover-foreground border-border">
          <.menu>
            <.menu_group>
              <.theme_option theme="light" icon="sun" />
              <.theme_option theme="dark" icon="moon" />
            </.menu_group>
          </.menu>
        </.dropdown_menu_content>
      </.dropdown_menu>
    </div>
    """
  end

  # Theme option menu item
  attr :theme, :string, required: true
  attr :icon, :string, required: true
  defp theme_option(assigns) do
    ~H"""
    <.menu_item
      id={"theme-#{@theme}-selector"}
      phx-click={
        JS.dispatch("set-theme", detail: %{theme: @theme})
        |> JS.push("change_theme", value: %{theme: @theme})
      }
      class="hover:bg-accent hover:text-accent-foreground"
    >
      <.icon name={"hero-#{@icon}"} class="mr-2 h-4 w-4" />
      <span><%= String.capitalize(@theme) %></span>
    </.menu_item>
    """
  end
end
