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
  # Store the current theme
  attr :current_theme, :string, default: "light"
  # Pass the navigation items
  attr :settings_nav_items, :list, default: @settings_nav_items

  def settings_dialog(assigns) do
    ~H"""
    <div>
      <.dialog id={@id} class="sm:max-w-[880px] p-0 flex gap-0 bg-background text-foreground ">
        <div class="flex flex-row w-full">
          <!-- Settings Sidebar -->
          <div class="flex w-[200px] flex-col gap-4 border-r border-border text-sidebar-foreground p-4 overflow-hidden">
            <.dialog_header class="px-2">
              <div class="text-foreground font-medium">Settings</div>
            </.dialog_header>
            <div class="h-[500px] overflow-y-auto">
              <div class="flex flex-col gap-1">
                <%= for item <- @settings_nav_items do %>
                  <.button
                    variant="ghost"
                    class={"justify-start gap-2 text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground #{if item.is_active, do: "bg-sidebar-accent text-sidebar-accent-foreground"}"}
                  >
                    <span class="h-4 w-4 flex items-center">
                      <.icon name={"hero-#{item.icon}"} class="h-4 w-4" />
                    </span>
                    <span>{item.title}</span>
                  </.button>
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

  attr :current_theme, :string, required: true

  def theme_selector(assigns) do
    ~H"""
    <div id="theme-selector" phx-update="ignore">
      <.dropdown_menu>
        <.dropdown_menu_trigger>
          <.button
            variant="outline"
            size="sm"
            class="flex items-center gap-2 bg-background border-border text-foreground hover:bg-accent hover:text-accent-foreground"
            id="theme-dropdown-trigger"
          >
            <%= if @current_theme == "light" do %>
              <span class="h-4 w-4 flex items-center">
                <.icon name="hero-sun" class="h-4 w-4" />
              </span>
              <span>Light</span>
            <% else %>
              <span class="h-4 w-4 flex items-center">
                <.icon name="hero-moon" class="h-4 w-4" />
              </span>
              <span>Dark</span>
            <% end %>
          </.button>
        </.dropdown_menu_trigger>
        <.dropdown_menu_content align="end" class="bg-popover text-popover-foreground border-border">
          <.menu>
            <.menu_group>
              <.menu_item
                id="theme-light-selector"
                phx-click={
                  JS.dispatch("set-theme", detail: %{theme: "light"})
                  |> JS.push("change_theme", value: %{theme: "light"})
                }
                class="hover:bg-accent hover:text-accent-foreground"
              >
                <.icon name="hero-sun" class="mr-2 h-4 w-4" />
                <span>Light</span>
              </.menu_item>
              <.menu_item
                id="theme-dark-selector"
                phx-click={
                  JS.dispatch("set-theme", detail: %{theme: "dark"})
                  |> JS.push("change_theme", value: %{theme: "dark"})
                }
                class="hover:bg-accent hover:text-accent-foreground"
              >
                <.icon name="hero-moon" class="mr-2 h-4 w-4" />
                <span>Dark</span>
              </.menu_item>
            </.menu_group>
          </.menu>
        </.dropdown_menu_content>
      </.dropdown_menu>
    </div>
    """
  end
end
