defmodule CentralWeb.PageHTML do
  use CentralWeb, :html
  use SaladUI

  @data [
    %{title: "Homepage", url: "/", items: [%{title: "Home", url: "/", is_active: true}]},
    %{
      title: "Settings",
      url: "#",
      items: [%{title: "Profile", url: "#profile"}, %{title: "Preferences", url: "#preferences"}]
    }
  ]

  def index(assigns) do
    assigns = Map.put(assigns, :data, @data)

    ~H"""
    <.sidebar_provider>
      <.sidebar id="main-sidebar">
        <.sidebar_content>
          <.sidebar_group :for={group <- @data}>
            <.sidebar_group_label>
              {group.title}
            </.sidebar_group_label>
            <.sidebar_group_content>
              <.sidebar_menu>
                <.sidebar_menu_item :for={item <- group.items}>
                  <.sidebar_menu_button is_active={item[:is_active]}>
                    <a href={item.url}>
                      {item.title}
                    </a>
                  </.sidebar_menu_button>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group_content>
          </.sidebar_group>
        </.sidebar_content>
        <.sidebar_rail></.sidebar_rail>
      </.sidebar>
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
end
