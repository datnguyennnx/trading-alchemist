defmodule CentralWeb.Components.Common.SettingsDialog do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  # Import the SaladUI components
  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Dialog
  import CentralWeb.Components.UI.Icon
  import CentralWeb.Components.UI.Select

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
      <span>{@item.title}</span>
    </.button>
    """
  end

  # Theme selector component
  attr :current_theme, :string, required: true

  def theme_selector(assigns) do
    ~H"""
    <div id="theme-selector" phx-hook="ThemeUIUpdater">
      <.select id="theme-select" value={@current_theme} name="theme">
        <.select_trigger
          builder={%{id: "theme-select", name: "theme", value: @current_theme, label: @current_theme == "light" && "Light" || "Dark"}}
          class="w-[120px] flex items-center gap-2 bg-background border-border text-foreground"
        />
        <.select_content builder={%{id: "theme-select", name: "theme", value: @current_theme}}>
          <.select_group>
            <.select_item
              builder={%{id: "theme-select", name: "theme", value: @current_theme}}
              value="light"
              label="Light"
              icon="hero-sun"
              phx-click={JS.push("change_theme", value: %{theme: "light"}) |> JS.dispatch("set-theme", detail: %{theme: "light"})}
            />
            <.select_item
              builder={%{id: "theme-select", name: "theme", value: @current_theme}}
              value="dark"
              label="Dark"
              icon="hero-moon"
              phx-click={JS.push("change_theme", value: %{theme: "dark"}) |> JS.dispatch("set-theme", detail: %{theme: "dark"})}
            />
          </.select_group>
        </.select_content>
      </.select>
    </div>
    """
  end
end
