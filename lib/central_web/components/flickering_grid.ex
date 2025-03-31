defmodule CentralWeb.Components.FlickeringGrid do
  @moduledoc false
  use CentralWeb.Component

  @doc """
  Renders a flickering grid visualization.

  ## Examples

      <.flickering_grid
        id="my-grid"
        square_size={4}
        grid_gap={6}
        flicker_chance={0.3}
        color="rgb(0, 0, 0)"
        max_opacity={0.3}
        class="w-full h-full"
      />
  """
  attr :id, :string, required: true
  attr :square_size, :integer, default: 4
  attr :grid_gap, :integer, default: 6
  attr :flicker_chance, :float, default: 0.3
  attr :color, :string, default: "rgb(0, 0, 0)"
  attr :width, :integer, default: nil
  attr :height, :integer, default: nil
  attr :max_opacity, :float, default: 0.3
  attr :class, :string, default: nil
  attr :rest, :global

  def flickering_grid(assigns) do
    ~H"""
    <div
      id={@id <> "-container"}
      class={classes(["relative w-full h-full", @class])}
      phx-hook="FlickeringGrid"
      data-square-size={@square_size}
      data-grid-gap={@grid_gap}
      data-flicker-chance={@flicker_chance}
      data-color={@color}
      data-max-opacity={@max_opacity}
      {@rest}
    >
      <canvas
        id={@id <> "-canvas"}
        class="pointer-events-none absolute top-0 left-0 w-full h-full"
        phx-update="ignore"
      >
      </canvas>
    </div>
    """
  end
end
