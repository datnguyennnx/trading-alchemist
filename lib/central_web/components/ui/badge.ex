defmodule CentralWeb.Components.UI.Badge do
  @moduledoc false
  use CentralWeb.Component

  @doc """
  Renders a badge component

  ## Examples

      <.badge>Badge</.badge>
      <.badge variant="destructive">Badge</.badge>
  """
  attr :class, :string, default: nil

  attr :variant, :string,
    values: ~w(default secondary destructive outline success warning info accent),
    default: "default",
    doc: "the badge variant style"

  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    assigns = assign(assigns, :variant_class, variant(assigns))

    ~H"""
    <div
      class={
        classes([
          "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-bold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
          @variant_class,
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @variants %{
    variant: %{
      "default" => "border-transparent bg-primary text-primary-foreground hover:bg-primary/80",
      "secondary" => "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80",
      "destructive" => "border-transparent bg-destructive text-destructive-foreground hover:bg-destructive/80",
      "outline" => "text-foreground",
      "success" => "border-transparent bg-success text-success-foreground hover:bg-success/80",
      "warning" => "border-transparent bg-warning text-warning-foreground hover:bg-warning/80",
      "info" => "border-transparent bg-info text-info-foreground hover:bg-info/80",
      "accent" => "border-transparent bg-accent text-accent-foreground hover:bg-accent/80"
    }
  }

  @default_variants %{
    variant: "default"
  }

  defp variant(props) do
    variants = Map.merge(@default_variants, props)

    Enum.map_join(variants, " ", fn {key, value} -> @variants[key][value] end)
  end
end
