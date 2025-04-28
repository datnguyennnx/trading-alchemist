defmodule CentralWeb.Components.UI.Checkbox do
  @moduledoc false
  use CentralWeb.Component

  @doc """
  Implement checkbox input component

  ## Examples:
      <.checkbox class="!border-destructive" name="agree" value={true} />
  """
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :"default-value", :any, values: [true, false, "true", "false"], default: false
  attr :checked, :boolean, default: nil
  attr :field, Phoenix.HTML.FormField
  attr :class, :string, default: nil
  attr :rest, :global

  def checkbox(assigns) do
    assigns =
      prepare_assign(assigns)

    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns.value)
      end)

    ~H"""
    <input type="hidden" name={@name} value="false" />
    <input
      type="checkbox"
      class={
        classes([
          "peer h-4 w-4 shrink-0 rounded-sm border border-primary shadow bg-background text-primary focus:ring-2 focus:ring-offset-2 focus:ring-primary disabled:cursor-not-allowed disabled:cursor-not-allowed disabled:opacity-50 checked:bg-primary checked:focus:bg-primary checked:hover:bg-primary checked:text-primary-foreground",
          @class
        ])
      }
      name={@name}
      value="true"
      checked={@checked}
      {@rest}
    />
    """
  end
end
