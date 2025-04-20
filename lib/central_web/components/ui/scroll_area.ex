defmodule CentralWeb.Components.UI.ScrollArea do
  @moduledoc """
  ScrollArea component for creating scrollable containers with customizable behavior.

  Part of the SaladUI component library.
  """
  use CentralWeb.Component

  @doc """
  Renders a scrollable area with customizable properties.

  ## Examples

  Basic usage:
  ```elixir
  <.scroll_area>
    <div class="p-4">
      <h4 class="mb-4 text-sm font-medium leading-none">Tags</h4>
      <%= for tag <- 1..50 do %>
        <div class="text-sm">v1.2.0-beta.<%= tag %></div>
        <.separator class="my-2" />
      <% end %>
    </div>
  </.scroll_area>
  ```

  With custom max height and horizontal scrolling:
  ```elixir
  <.scroll_area max_height="500px" orientation="both" class="border rounded">
    <div class="p-4" style="min-width: 800px;">
      <h4 class="mb-4 text-sm font-medium leading-none">Wide Content</h4>
      <!-- Content here -->
    </div>
  </.scroll_area>
  ```
  """
  attr :class, :string, default: nil, doc: "Additional CSS classes to apply to the component"
  attr :max_height, :string, default: "300px", doc: "Maximum height of the scroll area"
  attr :orientation, :string, default: "vertical", values: ["vertical", "horizontal", "both"], doc: "Scroll direction: vertical, horizontal, or both"
  attr :viewport_class, :string, default: nil, doc: "Additional CSS classes for the viewport"
  attr :rest, :global, doc: "Additional HTML attributes to apply to the component"
  slot :inner_block, required: true, doc: "Content to be placed inside the scroll area"

  def scroll_area(assigns) do
    ~H"""
    <div
      class={classes([
        "relative",
        @class
      ])}
      {@rest}
    >
      <div
        class={classes([
          "salad-scroll-viewport overflow-hidden",
          case @orientation do
            "vertical" -> "overflow-y-scroll"
            "horizontal" -> "overflow-x-scroll"
            "both" -> "overflow-scroll"
          end,
          @viewport_class
        ])}
        style={"max-height: #{@max_height}; scrollbar-width: none; -ms-overflow-style: none;"}
        phx-no-format
      >
        <div class="relative">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end
end
