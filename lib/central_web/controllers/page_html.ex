defmodule CentralWeb.PageHTML do
  use CentralWeb, :html

  import CentralWeb.ComponentHelpers
  import SaladUI.Sidebar
  import SaladUI.Collapsible

  import Lucideicons, except: [import: 1, quote: 1, menu: 1]

  @data %{
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
            url: "#"
          }
        ]
      }
    ]
  }

  def mount(_params, _session, socket) do
    {:ok, assign(socket, %{data: @data})}
  end

  def index(assigns) do
    assigns = Map.put(assigns, :data, @data)

    ~H"""
    <.sidebar_provider>
      <.sidebar_main data={@data}></.sidebar_main>
      <.sidebar_inset>
        <header class="flex h-16 shrink-0 items-center gap-2 border-b px-4">
          <.sidebar_trigger target="main-sidebar" class="-ml-1">
            <Lucideicons.panel_left class="w-4 h-4" />
          </.sidebar_trigger>
        </header>
        <div class="flex flex-1 flex-col gap-4 p-4">
          <div class="grid auto-rows-min gap-4 md:grid-cols-3">
            <div class="aspect-video rounded-xl bg-muted/50"></div>
            <div class="aspect-video rounded-xl bg-muted/50"></div>
            <div class="aspect-video rounded-xl bg-muted/50"></div>
          </div>
          <div class="min-h-[100vh] flex-1 rounded-xl bg-muted/50 md:min-h-min"></div>
        </div>
      </.sidebar_inset>
    </.sidebar_provider>
    """
  end

  def sidebar_main(assigns) do
    ~H"""
    <.sidebar collapsible="icon" id="main-sidebar">
      <.sidebar_header></.sidebar_header>
      <.sidebar_content>
        <.nav_main items={@data.navMain} />
      </.sidebar_content>
      <.sidebar_footer></.sidebar_footer>
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
          id={id(item.title)}
          open={item[:is_active]}
          class="group/collapsible block"
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
end
