defmodule CentralWeb.Components.Common.AppSidebar do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  import CentralWeb.ComponentHelpers

  import SaladUI.Sidebar
  import SaladUI.Collapsible
  import SaladUI.Icon, only: [icon: 1]

  import Lucideicons, except: [import: 1, quote: 1, menu: 1]
  alias CentralWeb.Components.Common.SettingsDialog

  # Define default sidebar navigation data
  @default_data %{
    navMain: [
      %{
        title: "Playground",
        url: "#",
        icon: &square_terminal/1,
        is_active: true,
        items: [
          %{
            title: "Money Track",
            url: "#"
          }
        ]
      },
      %{
        title: "Documentation",
        url: "#",
        icon: &book_open/1,
        items: [
          %{
            title: "Changelog",
            url: "/changelog"
          }
        ]
      }
    ]
  }

  # Define settings data
  @settings_data %{
    title: "Settings",
    icon: "hero-cog-6-tooth",
    dialog_id: "settings-dialog",
    trigger_id: "settings-dialog-trigger"
  }

  attr :data, :map, default: @default_data
  attr :settings_data, :map, default: @settings_data
  attr :theme, :string, default: "light"

  attr :id, :string, default: "theme-container"
  attr :class, :string, default: nil

  def sidebar_main(assigns) do
    ~H"""
    <.sidebar collapsible="icon" id="main-sidebar">
      <.sidebar_header></.sidebar_header>
      <.sidebar_content>
        <.nav_main items={@data.navMain} />
      </.sidebar_content>
      <.sidebar_footer>
        <.sidebar_menu_button
          id={@settings_data.trigger_id}
          phx-click={JS.exec("phx-show-modal", to: "##{@settings_data.dialog_id}")}
        >
          <span class="mr-2 h-4 w-4 flex items-center">
            <.icon name={@settings_data.icon} class="h-4 w-4" />
          </span>
          <span>{@settings_data.title}</span>
        </.sidebar_menu_button>

        <SettingsDialog.settings_dialog
          id={@settings_data.dialog_id}
          trigger_id={@settings_data.trigger_id}
          current_theme={@theme}
        />
      </.sidebar_footer>
      <.sidebar_rail />
    </.sidebar>
    """
  end

  def nav_main(assigns) do
    ~H"""
    <.sidebar_group>
      <.sidebar_group_label>
        Monitoring
      </.sidebar_group_label>
      <.sidebar_menu>
        <.collapsible
          :for={item <- @items}
          id={generate_id(item.title)}
          open={item[:is_active]}
          class="group/collapsible block overflow-hidden"
        >
          <.sidebar_menu_item>
            <.as_child
              tag={&collapsible_trigger/1}
              child={&sidebar_menu_button/1}
              tooltip={item.title}
            >
              <.dynamic :if={not is_nil(item.icon)} tag={item.icon} />

              <span>
                {item.title}
              </span>
              <.chevron_right class="ml-auto transition-transform duration-200 group-data-[state=open]/collapsible:rotate-90" />
            </.as_child>
            <.collapsible_content>
              <.sidebar_menu_sub>
                <.sidebar_menu_sub_item :for={sub_item <- item.items}>
                  <.as_child tag={&sidebar_menu_sub_button/1} child="a" href={sub_item.url}>
                    <span>
                      {sub_item.title}
                    </span>
                  </.as_child>
                </.sidebar_menu_sub_item>
              </.sidebar_menu_sub>
            </.collapsible_content>
          </.sidebar_menu_item>
        </.collapsible>
      </.sidebar_menu>
    </.sidebar_group>
    """
  end

  attr :data, :map, default: @default_data
  attr :theme, :string, default: "light"
  attr :id, :string, default: "theme-container"
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def app_layout(assigns) do
    ~H"""
    <div id={@id} phx-hook="ThemeSwitcher" data-connected="false" class={@class}>
      <.sidebar_provider>
        <.sidebar_main data={@data} theme={@theme} />
        <.sidebar_inset>
          <header class="flex h-16 shrink-0 items-center gap-2 px-4">
            <.sidebar_trigger target="main-sidebar" class="-ml-1">
              <Lucideicons.panel_left class="w-4 h-4" />
            </.sidebar_trigger>
          </header>
          <div class="flex flex-1 flex-col gap-4 p-4">
            {render_slot(@inner_block)}
          </div>
        </.sidebar_inset>
      </.sidebar_provider>
    </div>
    """
  end

  # Helper function for generating IDs
  defp generate_id(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w-]+/u, "-")
  end
end
