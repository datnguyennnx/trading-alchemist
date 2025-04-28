defmodule CentralWeb.Components.UI.Select do
  @moduledoc """
  Implementation of select components using application theme variables.

  For detailed usage examples and documentation, see `CentralWeb.Components.UI.SelectDocs`.
  """
  use CentralWeb.Component
  import CentralWeb.Components.UI.Icon

  @doc """
  Renders a customizable select dropdown component.

  ## Examples

      <.select :let={builder} id="basic-select" name="basic" value={@selected_value}>
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item builder={builder} value="option1" label="Option 1" />
          <.select_item builder={builder} value="option2" label="Option 2" />
        </.select_content>
      </.select>

      <.select :let={builder} field={@form[:category_id]} value={@selected_category_id}>
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item
            :for={category <- @categories}
            builder={builder}
            value={category.id}
            label={category.name}
          />
        </.select_content>
      </.select>

      <.select :let={builder} id="with-events" name="events_demo" value={@selected_value}>
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item
            builder={builder}
            value="option1"
            label="Option 1"
            event_name="option_selected"
            myself={@myself}  # For use in LiveComponents
          />
        </.select_content>
      </.select>
  """

  attr :id, :string, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil, doc: "The value of the select"
  attr :"default-value", :any, default: nil, doc: "The default value of the select"

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :label, :string,
    default: nil,
    doc: "The display label of the select value. If not provided, the value will be used."

  attr :placeholder, :string, default: nil, doc: "The placeholder text when no value is selected."

  attr :class, :string, default: nil
  attr :side, :string, values: ~w(top bottom), default: "bottom"
  attr :selected_label, :string, default: nil, doc: "Explicit label to display for the selected value."
  slot :inner_block, required: true
  attr :rest, :global

  def select(assigns) do
    assigns = process_select_assigns(assigns)

    options = assigns[:options] || []

    initial_label = cond do
      assigns.selected_label -> assigns.selected_label
      assigns.value -> find_label_for_value(options, assigns.value) || assigns.value
      true -> nil
    end

    assigns =
      assign(assigns, :builder, %{
        id: assigns.id,
        name: assigns.name,
        value: assigns.value,
        label: assigns.selected_label || initial_label,
        placeholder: assigns.placeholder
      })

    ~H"""
    <div
      id={@id}
      class={classes(["relative group transition-all duration-150", @class])}
      data-state="closed"
      {@rest}
      x-hide-select={hide_select(@id)}
      x-show-select={show_select(@id)}
      x-toggle-select={toggle_select(@id)}
      phx-click-away={JS.exec("x-hide-select")}
    >
      <%= render_slot(@inner_block, @builder) %>
    </div>
    """
  end

  attr :builder, :map, required: true, doc: "The builder of the select component"
  attr :class, :string, default: nil
  slot :inner_block, required: false
  attr :rest, :global

  @doc """
  Renders the trigger button for the select dropdown.

  Must be used within a select component and receive the builder prop.

  ## Examples

      <.select :let={builder} id="select-id" name="select_name">
        <.select_trigger builder={builder} />
        <!-- ... -->
      </.select>

      <.select :let={builder} id="custom-trigger" name="custom_select">
        <.select_trigger builder={builder} class="custom-class">
          <div class="flex items-center gap-2">
            <.icon name="hero-cog-6-tooth" class="h-4 w-4" />
            <span>{builder.label || "Custom Trigger"}</span>
          </div>
        </.select_trigger>
        <!-- ... -->
      </.select>
  """
  def select_trigger(assigns) do
    ~H"""
    <button
      type="button"
      class={
        classes([
          "flex h-10 w-full items-center justify-between rounded-[var(--radius)] border border-input bg-background px-4 py-2 text-sm font-medium shadow-sm ring-offset-background transition-colors",
          "hover:bg-accent hover:text-accent-foreground",
          "focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-1",
          "disabled:cursor-not-allowed disabled:opacity-50",
          "group-data-[state=open]:border-primary",
          "[&>span]:line-clamp-1",
          @class
        ])
      }
      phx-click={toggle_select(@builder.id)}
      {@rest}
    >
      <%= if render_slot(@inner_block) do %>
        {render_slot(@inner_block)}
      <% else %>
        <span
          class="select-value pointer-events-none font-medium before:content-[attr(data-content)]"
          data-content={@builder.label || @builder.placeholder}
        >
        </span>
      <% end %>
      <.icon
        name="hero-chevron-down"
        class="h-4 w-4 opacity-70 transition-transform group-data-[state=open]:rotate-180"
      />
    </button>
    """
  end

  attr :builder, :map, required: true, doc: "The builder of the select component"
  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  @doc """
  Renders the dropdown content container for the select options.

  Must be used within a select component and receive the builder prop.

  ## Examples

      <.select :let={builder} id="select-id" name="select_name">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item builder={builder} value="option1" label="Option 1" />
          <.select_item builder={builder} value="option2" label="Option 2" />
        </.select_content>
      </.select>

      <.select :let={builder} id="custom-position" name="positioned_select">
        <.select_trigger builder={builder} />
        <.select_content builder={builder} side="top" class="custom-class">
          <!-- Select items -->
        </.select_content>
      </.select>
  """
  def select_content(assigns) do
    position_class =
      case Map.get(assigns, :side, "bottom") do
        "top" -> "bottom-full mb-1"
        "bottom" -> "top-full mt-1"
      end

    assigns =
      assigns
      |> assign(:position_class, position_class)
      |> assign(:id, assigns.builder.id <> "-content")
      |> assign(:side, Map.get(assigns, :side, "bottom"))

    ~H"""
    <.focus_wrap
      id={@id}
      data-side={@side}
      class={
        classes([
          "select-content absolute hidden w-full",
          "z-50 min-w-[12rem] rounded-[var(--radius)] border border-input bg-popover text-popover-foreground shadow-lg",
          "group-data-[state=open]:animate-in group-data-[state=closed]:animate-out",
          "group-data-[state=closed]:fade-out-0 group-data-[state=open]:fade-in-0",
          "group-data-[state=closed]:zoom-out-95 group-data-[state=open]:zoom-in-95",
          "data-[side=bottom]:slide-in-from-top-2 data-[side=top]:slide-in-from-bottom-2",
          @position_class,
          @class
        ])
      }
      {@rest}
    >
      <div class="w-full p-1">
        {render_slot(@inner_block)}
      </div>
    </.focus_wrap>
    """
  end

  attr :class, :string, default: nil
  attr :side, :string, values: ~w(top bottom), default: "bottom"
  slot :inner_block, required: true
  attr :rest, :global

  @doc """
  Renders a group container for select items.

  ## Examples

      <.select :let={builder} id="grouped-select" name="grouped">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_group>
            <.select_label>Group Title</.select_label>
            <.select_item builder={builder} value="option1" label="Option 1" />
            <.select_item builder={builder} value="option2" label="Option 2" />
          </.select_group>
        </.select_content>
      </.select>
  """
  def select_group(assigns) do
    ~H"""
    <div role="group" class={classes(["py-1", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  @doc """
  Renders a label within a select group.

  ## Examples

      <.select :let={builder} id="with-label" name="labeled_select">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_group>
            <.select_label>Category</.select_label>
            <.select_item builder={builder} value="option1" label="Option 1" />
          </.select_group>
        </.select_content>
      </.select>

      <.select :let={builder} id="custom-label" name="custom_label">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_group>
            <.select_label class="custom-class">Custom Label</.select_label>
            <.select_item builder={builder} value="option1" label="Option 1" />
          </.select_group>
        </.select_content>
      </.select>
  """
  def select_label(assigns) do
    ~H"""
    <div class={classes(["py-1.5 px-3 text-sm font-semibold text-muted-foreground", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :builder, :map, required: true, doc: "The builder of the select component"
  attr :value, :string, required: true
  attr :label, :string, default: nil
  attr :icon, :string, default: nil, doc: "Icon name to display (e.g., 'hero-sun')"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :target_selector, :string, default: nil, doc: "Selector for the target component receiving the event."
  attr :event_name, :string, default: nil, doc: "The custom event name to push."
  attr :target, :any, default: nil, doc: "The target component/LiveView PID or CID for the event."
  attr :myself, :any, default: nil, doc: "The current component's assigns to direct events back."
  attr :rule_type, :string, default: nil, doc: "Rule type (entry/exit) for event payload."
  attr :index, :any, default: nil, doc: "Rule index for event payload."
  slot :inner_block, required: false

  attr :rest, :global

  @doc """
  Renders a selectable item within the select dropdown.

  ## Basic Example

      <.select :let={builder} id="basic-example" name="basic">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item builder={builder} value="option1" label="Option 1" />
        </.select_content>
      </.select>

  ## With Icon

      <.select :let={builder} id="with-icon" name="theme">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item builder={builder} value="light" label="Light Theme" icon="hero-sun" />
        </.select_content>
      </.select>

  ## With Event Handling

      <.select :let={builder} id="with-event" name="event_demo">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item
            builder={builder}
            value="option1"
            label="Option 1"
            event_name="option_selected"
          />
        </.select_content>
      </.select>

  ## Targeting Components

      <!-- Send to parent -->
      <.select :let={builder} id="parent-event" name="parent_target">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item builder={builder} value="v1" event_name="selected" />
        </.select_content>
      </.select>

      <!-- Send to specific DOM element -->
      <.select :let={builder} id="dom-event" name="dom_target">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item builder={builder} value="v1" event_name="selected" target_selector="#my-component" />
        </.select_content>
      </.select>

      <!-- Send to the component itself (in LiveComponent) -->
      <.select :let={builder} id="self-event" name="self_target">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item builder={builder} value="v1" event_name="selected" myself={@myself} />
        </.select_content>
      </.select>

      <!-- Send to another LiveComponent -->
      <.select :let={builder} id="component-event" name="component_target">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item builder={builder} value="v1" event_name="selected" target={@target_component_id} />
        </.select_content>
      </.select>

  ## With Additional Payload

      <.select :let={builder} id="with-payload" name="rule_demo">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_item
            builder={builder}
            value="allow"
            label="Allow Rule"
            event_name="rule_selected"
            rule_type="entry"
            index={0}
          />
        </.select_content>
      </.select>
  """
  def select_item(assigns) do
    assigns = assign_new(assigns, :label, fn -> assigns.value end)
    assigns = update_in(assigns, [:index], fn
      idx when is_binary(idx) -> String.to_integer(idx)
      idx -> idx
    end)

    ~H"""
    <label
      role="option"
      class={
        classes([
          "group/item",
          "relative flex w-full cursor-pointer select-none items-center rounded-[calc(var(--radius)-0.125rem)] py-2 pl-3 pr-8 text-sm z-100",
          "transition-colors outline-none",
          @builder.value == @value && "bg-accent text-accent-foreground",
          @builder.value != @value && "hover:bg-accent/50 hover:text-accent-foreground",
          "data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
          @class
        ])
      }
      {%{"data-disabled": @disabled}}
      phx-click={select_item_js(@builder.id, @value, @label, @target_selector, @event_name, @rule_type, @index, @target, @myself)}
      {@rest}
    >
      <input
        type="radio"
        class="peer w-0 opacity-0"
        name={@builder.name}
        value={@value}
        checked={@builder.value == @value}
        disabled={@disabled}
        phx-key="Escape"
        phx-keydown={JS.exec("x-hide-select", to: "##{@builder.id}")}
      />
      <div class="z-10 flex items-center gap-2">
        <%= if @icon do %>
          <span class="flex h-5 w-5 items-center justify-center text-primary">
            <.icon name={@icon} class="h-4 w-4" />
          </span>
        <% end %>
        <span class={@builder.value == @value && "font-medium"}>{@label}</span>
      </div>
      <span
        class={classes([
          "absolute right-3 flex h-5 w-5 items-center justify-center text-primary",
          if(@builder.value != @value, do: "opacity-0", else: "opacity-100")
        ])}
      >
        <.icon name="hero-check" class="h-4 w-4" />
      </span>
    </label>
    """
  end

  @doc """
  Renders a separator line between select items or groups.

  ## Example

      <.select :let={builder} id="with-separator" name="grouped_demo">
        <.select_trigger builder={builder} />
        <.select_content builder={builder}>
          <.select_group>
            <!-- First group items -->
          </.select_group>
          <.select_separator />
          <.select_group>
            <!-- Second group items -->
          </.select_group>
        </.select_content>
      </.select>
  """
  def select_separator(assigns) do
    ~H"""
    <div class={classes(["-mx-1 my-1 h-px bg-muted"])}></div>
    """
  end

  defp hide_select(id) do
    %JS{}
    |> JS.pop_focus()
    |> JS.add_class("hidden",
      transition: "ease-out",
      to: "##{id}[data-state=open] .select-content",
      time: 150
    )
    |> JS.set_attribute({"data-state", "closed"}, to: "##{id}")
  end

  # show select and focus first selected item or first item if no selected item
  defp show_select(id) do
    %JS{}
    # show if closed
    |> JS.focus_first(to: "##{id}[data-state=closed] .select-content")
    |> JS.set_attribute({"data-state", "open"}, to: "##{id}")
    |> JS.focus_first(to: "##{id}[data-state=open] .select-content")
    |> JS.focus_first(to: "##{id}[data-state=open] .select-content label:has(input:checked)")
  end

  # show or hide select
  defp toggle_select(id) do
    %JS{}
    |> JS.add_class("hidden",
      transition: "ease-out",
      to: "##{id}[data-state=open] .select-content",
      time: 150
    )
    # show if closed
    |> JS.remove_class("hidden", to: "##{id}[data-state=closed] .select-content")
    |> JS.toggle_attribute({"data-state", "open", "closed"}, to: "##{id}")
    |> JS.focus_first(to: "##{id}[data-state=open] .select-content")
    |> JS.focus_first(to: "##{id}[data-state=open] .select-content label:has(input:checked)")
  end

  defp find_label_for_value(options, value) do
    Enum.find_value(options, fn
      %{value: v, label: l} when v == value -> l
      %{value: v, key: k} when v == value -> k
      {l, v} when v == value -> l
      _ -> nil
    end)
  end

  # New JS helper to push event on item select
  defp select_item_js(root_id, value, label, target_selector, event_name, rule_type, index, target, myself) do
    js = %JS{}
         # Set display value using the item's LABEL
         |> JS.set_attribute({"data-content", label || value}, to: "##{root_id} .select-value")
         |> JS.exec("x-hide-select", to: "##{root_id}")

    # Only push the event if event_name is provided
    cond do
      event_name && target_selector ->
        # When target_selector is provided, push to that DOM element
        JS.push(js, event_name, target: target_selector, value: %{value: value, rule_type: rule_type, index: index})

      event_name && myself ->
        # When myself is provided, push to the component itself
        JS.push(js, event_name, target: myself, value: %{value: value, rule_type: rule_type, index: index})

      event_name && target ->
        # When target is provided, push to that component/LiveView
        JS.push(js, event_name, target: target, value: %{value: value, rule_type: rule_type, index: index})

      event_name ->
        # When no target is provided, push to the parent LiveView
        JS.push(js, event_name, value: %{value: value, rule_type: rule_type, index: index})

      true ->
        js
    end
  end

  # Prepare assigns for the select component
  defp process_select_assigns(assigns) do
    assigns = if assigns[:field] do
      name = assigns.field.name
      id = assigns.field.id || "#{name}_select"

      %{
        assigns
        | id: id,
          name: name,
          value: Phoenix.HTML.Form.input_value(assigns.field.form, assigns.field.field)
      }
    else
      # Generate an ID if not provided
      id = assigns[:id] || "select-#{System.unique_integer([:positive])}"
      name = assigns[:name] || id

      %{assigns | id: id, name: name}
    end

    # Process options if they exist in assigns
    if assigns[:options] do
      %{assigns | options: process_options(assigns.options)}
    else
      assigns
    end
  end

  # Process various option formats into a standardized form
  defp process_options(options) do
    Enum.map(options, fn
      # Handle maps with key/value or label/value fields
      %{key: key, value: value} ->
        {key, value}

      %{label: label, value: value} ->
        {label, value}

      # Handle string options
      option when is_binary(option) ->
        {option, option}

      # Handle atom options
      option when is_atom(option) ->
        {Atom.to_string(option), Atom.to_string(option)}

      # Handle tuple options
      {label, value} ->
        {label, value}

      # Default - convert to string
      option ->
        {to_string(option), to_string(option)}
    end)
  end
end
