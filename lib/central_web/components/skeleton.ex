defmodule CentralWeb.Components.Skeleton do
  @moduledoc false
  use CentralWeb.Component

  @doc """
  Render skeleton
  """
  attr :class, :string, default: nil
  attr :rest, :global

  def skeleton(assigns) do
    ~H"""
    <div
      class={
        classes([
          "animate-pulse rounded-md bg-muted dark:bg-muted",
          @class
        ])
      }
      {@rest}
    >
    </div>
    """
  end
end
