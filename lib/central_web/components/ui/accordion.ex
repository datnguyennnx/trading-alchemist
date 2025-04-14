defmodule CentralWeb.Components.UI.Accordion do
  @moduledoc """
  Accordion component for displaying collapsible content.

  ## Example

  <.accordion>
    <.accordion_item>
      <.accordion_trigger group="exclusive">
        Is it accessible?
      </.accordion_trigger>
      <.accordion_content>
        Yes. It adheres to the WAI-ARIA design pattern.
      </.accordion_content>
    </.accordion_item>
    <.accordion_item>
      <.accordion_trigger group="exclusive">
        Is it styled?
      </.accordion_trigger>
      <.accordion_content>
        Yes. It comes with default styles that matches the other components' aesthetic.
      </.accordion_content>
    </.accordion_item>
    <.accordion_item>
      <.accordion_trigger group="exclusive">
        Is it animated?
      </.accordion_trigger>
      <.accordion_content>
        Yes. It's animated by default, but you can disable it if you prefer.
      </.accordion_content>
    </.accordion_item>
  </.accordion>
  """
  use CentralWeb.Component
  alias CentralWeb.Components.UI.Icon

  # Icon component
  import Icon, only: [icon: 1]

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def accordion(assigns) do
    ~H"""
    <div class={classes(["", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  slot :inner_block, required: true

  def accordion_item(assigns) do
    ~H"""
    <div class={classes(["group/item mb-2", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :group, :string, default: nil
  attr :class, :string, default: nil
  attr :open, :boolean, default: false
  attr :disabled, :boolean, default: false
  slot :inner_block, required: true
  attr :rest, :global

  def accordion_trigger(assigns) do
    ~H"""
    <details {@rest} name={@group} class={classes(["group/accordion peer/accordion cursor-pointer", @disabled && "opacity-50 pointer-events-none"])} open={@open} disabled={@disabled}>
      <summary class={
        classes([
          "flex flex-1 items-center justify-between p-4 font-medium transition-all rounded-md border border-input bg-background shadow-sm",
          !@disabled && "hover:bg-accent hover:text-accent-foreground",
          !@disabled && "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring",
          @class
        ])
      }>
        <p class="font-medium">
          {render_slot(@inner_block)}
        </p>

        <div :if={!@disabled}>
          <.icon
            name="hero-chevron-down"
            class="h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-200 group-open/accordion:rotate-180"
          />
        </div>
        <div :if={@disabled}>
          <.icon name="hero-no-symbol" class="h-4 w-4 shrink-0 text-muted-foreground" />
        </div>
      </summary>
    </details>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def accordion_content(assigns) do
    ~H"""
    <div class="text-sm overflow-hidden grid grid-rows-[0fr] transition-[grid-template-rows] duration-300 peer-open/accordion:grid-rows-[1fr]">
      <div class="overflow-hidden">
        <div class={classes(["my-4", @class])}>
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end
end
