defmodule CentralWeb.Components.UI.DropdownMenu do
  @moduledoc false
  use CentralWeb.Component

  alias Phoenix.LiveView.JS

  @spec dropdown_menu(map()) :: Phoenix.LiveView.Rendered.t()
  @doc """
  Render dropdown menu


  ## Examples:

      <.dropdown_menu>
        <.dropdown_menu_trigger>
          <.button variant="outline">Open</.button>
        </.dropdown_menu_trigger>

        <.dropdown_menu_content>
          <.dropdown_menu_label>Account</.dropdown_menu_label>
          <.dropdown_menu_separator />

          <.dropdown_menu_group>
            <.dropdown_menu_item>
              Profile
              <.dropdown_menu_shortcut>⌘P</.dropdown_menu_shortcut>
            </.dropdown_menu_item>
            <.dropdown_menu_item>
              Billing
              <.dropdown_menu_shortcut>⌘B</.dropdown_menu_shortcut>
            </.dropdown_menu_item>
            <.dropdown_menu_item>
              Settings
              <.dropdown_menu_shortcut>⌘S</.dropdown_menu_shortcut>
            </.dropdown_menu_item>
          </.dropdown_menu_group>
        </.dropdown_menu_content>
      </.dropdown_menu>
  """

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def dropdown_menu(assigns) do
    ~H"""
    <div class={classes(["relative group inline-block", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :as_tag, :any, default: "div"
  slot :inner_block, required: true

  attr :rest, :global

  def dropdown_menu_trigger(assigns) do
    ~H"""
    <.dynamic
      tag={@as_tag}
      class={classes(["dropdown-menu-trigger peer", @class])}
      data-state="closed"
      {@rest}
      phx-click={toggle()}
      phx-click-away={hide()}
    >
      {render_slot(@inner_block)}
    </.dynamic>
    """
  end

  attr :class, :string, default: nil
  attr :side, :string, values: ["top", "right", "bottom", "left"], default: "bottom"
  attr :align, :string, values: ["start", "center", "end"], default: "start"
  slot :inner_block, required: true
  attr :rest, :global

  def dropdown_menu_content(assigns) do
    assigns =
      assign(assigns, :variant_class, side_variant(assigns.side, assigns.align))

    ~H"""
    <div
      class={[
        "z-50 animate-in peer-data-[state=closed]:fade-out-0 peer-data-[state=open]:fade-in-0 peer-data-[state=closed]:zoom-out-95 peer-data-[state=open]:zoom-in-95 peer-data-[side=bottom]:slide-in-from-top-2 peer-data-[side=left]:slide-in-from-right-2 peer-data-[side=right]:slide-in-from-left-2 peer-data-[side=top]:slide-in-from-bottom-2",
        "absolute peer-data-[state=closed]:hidden",
        @variant_class,
        @class
      ]}
      {@rest}
    >
      <div class="min-w-[8rem] overflow-hidden rounded-md border border-border bg-popover p-1 text-popover-foreground shadow-md dark:border-border dark:bg-popover dark:text-popover-foreground">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Render
  """
  attr(:class, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def dropdown_menu_shortcut(assigns) do
    ~H"""
    <span
      class={
        classes([
          "ml-auto text-xs tracking-widest opacity-60 dark:opacity-70",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp toggle(js \\ %JS{}) do
    JS.toggle_attribute(js, {"data-state", "open", "closed"})
  end

  defp hide(js \\ %JS{}) do
    JS.set_attribute(js, {"data-state", "closed"})
  end
end
