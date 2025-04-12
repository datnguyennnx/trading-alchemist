defmodule CentralWeb.Components.UI.Menu do
  @moduledoc """
  Implement menu components
  """
  use CentralWeb.Component

  @doc """
  Render menu


  ## Examples:


      <.menu>
        <.menu_label>Account</.menu_label>
        <.menu_separator />

        <.menu_group>
          <.menu_item>
              Profile
            <.menu_shortcut>⌘P</.menu_shortcut>
          </.menu_item>

          <.menu_item>
              Billing
            <.menu_shortcut>⌘B</.menu_shortcut>
          </.menu_item>

          <.menu_item>
              Settings
            <.menu_shortcut>⌘S</.menu_shortcut>
          </.menu_item>
        </.menu_group>
      </.menu>
  """

  attr :class, :string, default: "top-0 left-full"
  slot :inner_block, required: true
  attr :rest, :global

  def menu(assigns) do
    ~H"""
    <div
      class={[
        "min-w-[8rem] overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-md data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 dark:border-border dark:bg-popover dark:text-popover-foreground",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  slot :inner_block, required: true
  attr :rest, :global

  def menu_item(assigns) do
    ~H"""
    <div
      class={
        classes([
          "relative flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none transition-colors focus:bg-accent focus:text-accent-foreground hover:bg-accent hover:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 dark:focus:bg-accent dark:focus:text-accent-foreground dark:hover:bg-accent dark:hover:text-accent-foreground",
          @class
        ])
      }
      {%{"data-disabled" => @disabled}}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :inset, :boolean, default: false
  slot :inner_block, required: true
  attr :rest, :global

  def menu_label(assigns) do
    ~H"""
    <div
      class={
        classes([
          "px-2 py-1.5 text-sm font-semibold text-muted-foreground dark:text-muted-foreground",
          @inset && "pl-8",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block

  def menu_separator(assigns) do
    ~H"""
    <div
      role="separator"
      aria-orientation="horizontal"
      class={classes(["-mx-1 my-1 h-px bg-border dark:bg-border", @class])}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def menu_shortcut(assigns) do
    ~H"""
    <span
      class={
        classes([
          "ml-auto text-xs tracking-widest text-muted-foreground dark:text-muted-foreground",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def menu_group(assigns) do
    ~H"""
    <div class={classes(["space-y-0.5", @class])} role="group" {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
