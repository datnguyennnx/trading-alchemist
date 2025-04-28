defmodule CentralWeb.Components.UI.Pagination do
  @moduledoc false
  use CentralWeb.Component
  import CentralWeb.Components.UI.Icon

  @doc """
  Renders a pagination.

  ## Examples

        <.pagination>
          <.pagination_content>
            <.pagination_item>
              <.pagination_previous href="#" />
            </.pagination_item>
            <.pagination_item>
              <.pagination_link href="">1</.pagination_link>
            </.pagination_item>
            <.pagination_item>
              <.pagination_link href="" is-active="true">2</.pagination_link>
            </.pagination_item>
            <.pagination_item>
              <.pagination_link href="">3</.pagination_link>
            </.pagination_item>
            <.pagination_item>
              <.pagination_ellipsis />
            </.pagination_item>
            <.pagination_item>
              <.pagination_next href="#" />
            </.pagination_item>
          </.pagination_content>
        </.pagination>

  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pagination(assigns) do
    ~H"""
    <nav
      arial-label="pagination"
      role="pagination"
      class={
        classes([
          "mx-auto flex w-full justify-center",
          @class
        ])
      }
      {@rest}
      }
    >
      {render_slot(@inner_block)}
    </nav>
    """
  end

  @doc """
  Render pagination content
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pagination_content(assigns) do
    ~H"""
    <ul
      class={
        classes([
          "flex flex-row items-center gap-1",
          @class
        ])
      }
      {@rest}
      }
    >
      {render_slot(@inner_block)}
    </ul>
    """
  end

  @doc """
  Render pagination item
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pagination_item(assigns) do
    ~H"""
    <li
      class={
        classes([
          "",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </li>
    """
  end

  @doc """
  Render pagination link
  """
  attr :"is-active", :boolean, default: false
  attr :size, :string, default: "icon"
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pagination_link(assigns) do
    is_active = assigns[:"is-active"] in [true, "true"]

    assigns =
      assigns
      |> assign(
        :variation_class,
        variant(%{size: assigns[:size], variant: (is_active && "outline") || "ghost"})
      )
      |> assign(:"is-active", is_active)

    ~H"""
    <.link
      aria-current={(assigns[:"is-active"] && "page") || ""}
      class={
        classes([
          "inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:ring-ring focus-visible:outline-none focus-visible:ring-1 disabled:pointer-events-none disabled:opacity-50",
          @variation_class,
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Render next button
  """
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def pagination_next(assigns) do
    ~H"""
    <.pagination_link
      aria-label="Go to next page"
      size="default"
      class={classes(["gap-1 pr-2.5", @class])}
      {@rest}
    >
      <p>Next</p>
      <.icon name="hero-chevron-right" class="h-4 w-4" />
    </.pagination_link>
    """
  end

  @doc """
  Render previous button
  """
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def pagination_previous(assigns) do
    ~H"""
    <.pagination_link
      aria-label="Go to previous page"
      size="default"
      class={classes(["gap-1 pr-2.5", @class])}
      {@rest}
    >
      <.icon name="hero-chevron-left" class="h-4 w-4" />
      <p>Previous</p>
    </.pagination_link>
    """
  end

  @doc """
  Render ellipsis
  """
  attr :class, :string, default: nil
  attr :rest, :global

  def pagination_ellipsis(assigns) do
    ~H"""
    <span
      class={
        classes([
          "flex h-9 w-9 items-center justify-center",
          @class
        ])
      }
      {@rest}
    >
      <.icon name="hero-ellipsis-horizontal" class="h-4 w-4" />
      <p class="sr-only">More pages</p>
    </span>
    """
  end

  @variants %{
    variant: %{
      "outline" => "border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground",
      "ghost" => "hover:bg-accent hover:text-accent-foreground"
    },
    size: %{
      "default" => "h-9 px-4 py-2",
      "sm" => "h-8 rounded-md px-3 text-xs",
      "lg" => "h-10 rounded-md px-8",
      "icon" => "h-9 w-9"
    }
  }

  defp variant(props) do
    variants =
      Map.take(props, ~w(variant size)a)

    Enum.map_join(variants, " ", fn {key, value} -> @variants[key][value] end)
  end
end
