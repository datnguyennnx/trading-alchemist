defmodule CentralWeb.Components.UI.Badge do
  @moduledoc false
  use CentralWeb.Component

  import CentralWeb.Components.UI.Icon

  @doc """
  Renders a badge component with optional icon and color styling.

  ## Examples

      <.badge>Default Badge</.badge>
      <.badge color="blue">Blue Badge</.badge>
      <.badge color="green" icon="hero-check-circle">Success</.badge>
  """
  attr :class, :string, default: nil

  attr :color, :string,
    values: ~w(gray orange amber yellow lime green emerald teal cyan sky blue indigo violet purple red pink rose),
    default: "gray",
    doc: "the badge color style"

  attr :icon, :string, default: nil, doc: "optional heroicon name to display before the text"

  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    assigns = assign(assigns, :color_class, color_classes(assigns.color))

    ~H"""
    <div
      class={
        classes([
          "inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-bold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
          @color_class,
          @class
        ])
      }
      {@rest}
    >
      <.icon :if={@icon} name={@icon} class="h-3 w-3 mr-1" />
      {render_slot(@inner_block)}
    </div>
    """
  end

  @color_map %{
    "gray" => "bg-gray-100 text-gray-800 border-gray-200 dark:bg-gray-800 dark:text-gray-300 dark:border-gray-700",
    "orange" => "bg-orange-100 text-orange-800 border-orange-200 dark:bg-orange-900 dark:text-orange-300 dark:border-orange-700",
    "amber" => "bg-amber-100 text-amber-800 border-amber-200 dark:bg-amber-900 dark:text-amber-300 dark:border-amber-700",
    "yellow" => "bg-yellow-100 text-yellow-800 border-yellow-200 dark:bg-yellow-900 dark:text-yellow-300 dark:border-yellow-700",
    "lime" => "bg-lime-100 text-lime-800 border-lime-200 dark:bg-lime-900 dark:text-lime-300 dark:border-lime-700",
    "green" => "bg-green-100 text-green-800 border-green-200 dark:bg-green-900 dark:text-green-300 dark:border-green-700",
    "emerald" => "bg-emerald-100 text-emerald-800 border-emerald-200 dark:bg-emerald-900 dark:text-emerald-300 dark:border-emerald-700",
    "teal" => "bg-teal-100 text-teal-800 border-teal-200 dark:bg-teal-900 dark:text-teal-300 dark:border-teal-700",
    "cyan" => "bg-cyan-100 text-cyan-800 border-cyan-200 dark:bg-cyan-900 dark:text-cyan-300 dark:border-cyan-700",
    "sky" => "bg-sky-100 text-sky-800 border-sky-200 dark:bg-sky-900 dark:text-sky-300 dark:border-sky-700",
    "blue" => "bg-blue-100 text-blue-800 border-blue-200 dark:bg-blue-900 dark:text-blue-300 dark:border-blue-700",
    "indigo" => "bg-indigo-100 text-indigo-800 border-indigo-200 dark:bg-indigo-900 dark:text-indigo-300 dark:border-indigo-700",
    "violet" => "bg-violet-100 text-violet-800 border-violet-200 dark:bg-violet-900 dark:text-violet-300 dark:border-violet-700",
    "purple" => "bg-purple-100 text-purple-800 border-purple-200 dark:bg-purple-900 dark:text-purple-300 dark:border-purple-700",
    "red" => "bg-red-100 text-red-800 border-red-200 dark:bg-red-900 dark:text-red-300 dark:border-red-700",
    "pink" => "bg-pink-100 text-pink-800 border-pink-200 dark:bg-pink-900 dark:text-pink-300 dark:border-pink-700",
    "rose" => "bg-rose-100 text-rose-800 border-rose-200 dark:bg-rose-900 dark:text-rose-300 dark:border-rose-700"
  }

  defp color_classes(color_value) do
    Map.get(@color_map, color_value, @color_map["gray"])
  end
end
