defmodule CentralWeb.StrategyLive.Components.IndicatorConfig do
  use Phoenix.LiveComponent

  import CentralWeb.Components.UI.Form
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.UI.Select
  import CentralWeb.Components.UI.Icon
  import CentralWeb.Components.UI.Badge
  import CentralWeb.Components.UI.Checkbox
  import CentralWeb.Components.UI.ScrollArea

  alias Central.Backtest.DynamicForm.FormGenerator
  alias Central.Backtest.Indicators.ListIndicator
  alias Central.Backtest.DynamicForm.FormContext

  @doc """
  This component renders the parameter form fields for a selected indicator.
  It automatically retrieves the parameter specifications for the given indicator
  and renders the appropriate form fields.
  """

  attr :indicator_id, :string, required: true
  attr :params, :map, default: %{}
  attr :name_prefix, :string, required: true

  def render(assigns) do
    ~H"""
    <div id={@id} class="indicator-config">
      <%= if @should_render_params do %>
        <div class="space-y-4 border border-gray-200 rounded-md p-4 bg-white">
          <div class="flex flex-col">
            <div class="flex items-center justify-between border-b pb-2 mb-2">
              <h2 class="font-bold text-foreground">
                <%= @processed_indicator.name %> Configuration
              </h2>

              <div class="flex items-center">
                <.badge
                  variant={indicator_type_variant(@processed_indicator.type)}
                  class="text-xs"
                >
                  <%= @processed_indicator.type |> Atom.to_string() |> String.capitalize() %> Indicator
                </.badge>
              </div>
            </div>

            <%= if @processed_indicator.description do %>
              <p class="text-xs text-gray-600 mb-3">
                <%= @processed_indicator.description %>
              </p>
            <% end %>
          </div>

          <div class="divide-y divide-gray-100">
            <%= for param <- @processed_params do %>
              <div class="py-3 first:pt-0 last:pb-0">
                <.render_param_input param={param} form={@form} path={@path} />
              </div>
            <% end %>
          </div>

          <div class="text-xs text-gray-500 mt-2 flex items-center">
            <.icon name="hero-information-circle" class="h-3.5 w-3.5 mr-1.5" />
            <span>Parameters are saved automatically when the strategy is created.</span>
          </div>
        </div>
      <% else %>
        <div class="p-4 border border-blue-100 bg-blue-50 rounded-md text-blue-700 text-sm flex items-center">
          <.icon name="hero-information-circle" class="h-5 w-5 mr-2 text-blue-500 flex-shrink-0" />
          <div>
            <%= if @indicator_id do %>
              <p class="font-medium">Using default parameters</p>
              <p class="text-blue-600 text-xs mt-1">This indicator will use standard settings designed for most trading scenarios.</p>
            <% else %>
              <p class="font-medium">Select an indicator</p>
              <p class="text-blue-600 text-xs mt-1">Choose a technical indicator from the dropdown above to configure trading rules.</p>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def update(assigns, socket) do
    # Generate an ID if not provided
    id = assigns[:id] || "indicator-config-#{assigns.indicator_id || "default"}"

    # Check if any key attributes have changed to avoid unnecessary processing
    if socket.assigns[:id] == id &&
       socket.assigns[:indicator_id] == assigns.indicator_id &&
       socket.assigns[:params] == assigns.params &&
       socket.assigns[:name_prefix] == assigns.name_prefix do
      # No changes in key attributes, avoid unnecessary processing
      {:ok, socket}
    else
      # Get params efficiently - use cached version if available in assigns
      params_list = get_cached_params(assigns.indicator_id, socket)

      # Efficiently determine params to use
      params = determine_params(assigns.params, params_list)

      # Process indicator data once
      {processed_indicator, processed_params} = process_indicator_data(
        assigns.indicator_id,
        params,
        params_list
      )

      # Determine if settings should be shown
      show_settings = processed_indicator != nil && length(processed_params) > 0

      # Extract name_prefix or use empty string
      name_prefix = assigns.name_prefix || ""

      {:ok, socket
        |> assign(:id, id)
        |> assign(:indicator_id, assigns.indicator_id)
        |> assign(:params, params)
        |> assign(:name_prefix, name_prefix)
        |> assign(:params_list, params_list)
        |> assign(:processed_indicator, processed_indicator)
        |> assign(:processed_params, processed_params)
        |> assign(:should_render_params, show_settings)
        |> assign(:form, assigns[:form] || %{})
        |> assign(:path, assigns[:path] || name_prefix)
      }
    end
  end

  # Get cached params or fetch new ones
  defp get_cached_params(indicator_id, socket) do
    # First check if we already have the params list cached in socket
    cond do
      # If indicator ID matches and we have cached params, use them
      socket.assigns[:indicator_id] == indicator_id &&
      socket.assigns[:params_list] != nil ->
        socket.assigns.params_list

      # Otherwise, get new params
      indicator_id && indicator_id != "" && indicator_id != "nil" ->
        ListIndicator.get_params(indicator_id)

      true ->
        []
    end
  end

  # Determine which params to use - existing, defaults, or empty
  defp determine_params(provided_params, params_list) do
    cond do
      # No params provided and indicator has parameters - generate defaults
      (is_nil(provided_params) || provided_params == %{}) && params_list != [] ->
        # Cache generated defaults for better performance
        FormContext.generate_default_params_map(params_list)

      # Params provided but might be nil - convert to empty map
      is_nil(provided_params) ->
        %{}

      # Use existing params
      true ->
        provided_params
    end
  end

  # Process indicator data using the FormGenerator
  defp process_indicator_data(indicator_id, params, _params_list) do
    if indicator_id && indicator_id != "" && indicator_id != "nil" do
      # Generate form configuration efficiently
      # Try to use pre-generated form config first
      form_config = FormGenerator.generate_indicator_form(indicator_id)

      if form_config do
        # Extract the indicator from the form config
        processed_indicator = %{
          id: form_config.id,
          name: form_config.name,
          description: form_config.description,
          type: form_config.type
        }

        # Process parameters with values from params or defaults
        processed_params = Enum.map(form_config.fields, fn field ->
          # Extract value from params or use default
          value = get_param_value(params, field.name, field)
          Map.put(field, :value, value)
        end)

        {processed_indicator, processed_params}
      else
        {nil, []}
      end
    else
      {nil, []}
    end
  end

  # Extract parameter value from params map, falling back to default if not found
  defp get_param_value(params, param_name, param_def) do
    default = Map.get(param_def, :default)

    # Return default if params is not a map
    if not is_map(params) do
      default
    else
      # Optimize the lookup process
      param_name_str = if is_atom(param_name), do: Atom.to_string(param_name), else: param_name

      cond do
        # Most common case first - direct match with atom key
        is_atom(param_name) && Map.has_key?(params, param_name) ->
          Map.get(params, param_name)

        # Check string version of the key
        Map.has_key?(params, param_name_str) ->
          Map.get(params, param_name_str)

        # Try to convert string to atom (least efficient path)
        is_binary(param_name) ->
          try do
            atom_key = String.to_existing_atom(param_name)
            if Map.has_key?(params, atom_key), do: Map.get(params, atom_key), else: default
          rescue
            ArgumentError -> default
          end

        # Default case
        true ->
          default
      end
    end
  end

  # Function to render different parameter inputs based on type
  defp render_param_input(assigns) do
    assigns =
      assigns
      |> assign_new(:param, fn -> Map.get(assigns, :param, %{}) end)
      |> assign_new(:form, fn -> Map.get(assigns, :form, %{}) end)
      |> assign_new(:path, fn -> Map.get(assigns, :path, "") end)

    param_name = Map.get(assigns.param, :name)
    param_type = Map.get(assigns.param, :type)
    param_value = Map.get(assigns.param, :value)
    param_label = Map.get(assigns.param, :label, humanize_param_name(param_name))
    param_description = Map.get(assigns.param, :description)

    # Create a well-formed assigns map with all needed values
    assigns = assign(assigns, :param_name, param_name)
    assigns = assign(assigns, :param_type, param_type)
    assigns = assign(assigns, :param_value, param_value)
    assigns = assign(assigns, :param_label, param_label)
    assigns = assign(assigns, :param_description, param_description)

    # Add step, min, max for number inputs
    assigns = assign(assigns, :step, Map.get(assigns.param, :step, "1"))
    assigns = assign(assigns, :min, Map.get(assigns.param, :min, nil))
    assigns = assign(assigns, :max, Map.get(assigns.param, :max, nil))

    # Add range info for display
    range_text = cond do
      assigns.min != nil && assigns.max != nil -> "(#{assigns.min}-#{assigns.max})"
      assigns.min != nil -> "(min: #{assigns.min})"
      assigns.max != nil -> "(max: #{assigns.max})"
      true -> ""
    end
    assigns = assign(assigns, :range_text, range_text)

    # Process options for select inputs
    assigns = if param_type == :select do
      options = Map.get(assigns.param, :options, [])

      # Convert options to a standardized format
      select_options = Enum.map(options, fn
        {label, value} -> %{key: to_string(label), value: to_string(value)}
        value when is_binary(value) -> %{key: humanize_value(value), value: value}
        value when is_atom(value) -> %{key: humanize_value(Atom.to_string(value)), value: Atom.to_string(value)}
        value -> %{key: to_string(value), value: to_string(value)}
      end)

      assign(assigns, :select_options, select_options)
    else
      assigns
    end

    # Render the appropriate input based on type
    case param_type do
      :number ->
        render_number_input(assigns)
      :select ->
        render_select_input(assigns)
      :checkbox ->
        render_checkbox_input(assigns)
      :text ->
        render_text_input(assigns)
      _ ->
        render_text_input(assigns)
    end
  end

  # Render helpers for different input types
  defp render_number_input(assigns) do
    ~H"""
    <.form_item>
      <.form_label>
        <%= @param_label %> <%= if @range_text != "", do: @range_text %>
      </.form_label>
      <.input
        type="number"
        name={"#{@path}_#{@param_name}"}
        value={@param_value}
        min={@min}
        max={@max}
        step={@step}
      />
      <%= if @param_description do %>
        <.form_description>
          <%= @param_description %>
        </.form_description>
      <% end %>
    </.form_item>
    """
  end

  defp render_select_input(assigns) do
    ~H"""
    <.form_item>
      <.form_label><%= @param_label %></.form_label>
      <.select
        :let={select}
        name={"#{@path}_#{@param_name}"}
        value={to_string(@param_value)}
        selected_label={humanize_value(to_string(@param_value))}
        placeholder={"Choose #{@param_label}"}
      >
        <.select_trigger builder={select} class="w-full" />
        <.select_content builder={select} class="w-full">
          <.scroll_area>
            <%= for option <- @select_options do %>
              <.select_item
                builder={select}
                value={option.value}
                label={option.key}
              />
            <% end %>
          </.scroll_area>
        </.select_content>
      </.select>
      <%= if @param_description do %>
        <.form_description>
          <%= @param_description %>
        </.form_description>
      <% end %>
    </.form_item>
    """
  end

  defp render_checkbox_input(assigns) do
    ~H"""
    <.form_item>
      <.form_control>
        <.checkbox
          name={"#{@path}_#{@param_name}"}
          checked={@param_value === true}
          value="true"
        />
        <.form_label><%= @param_label %></.form_label>
      </.form_control>
      <%= if @param_description do %>
        <.form_description>
          <%= @param_description %>
        </.form_description>
      <% end %>
    </.form_item>
    """
  end

  defp render_text_input(assigns) do
    ~H"""
    <.form_item>
      <.form_label><%= @param_label %></.form_label>
      <.input
        type="text"
        name={"#{@path}_#{@param_name}"}
        value={@param_value}
      />
      <%= if @param_description do %>
        <.form_description>
          <%= @param_description %>
        </.form_description>
      <% end %>
    </.form_item>
    """
  end

  # Helper functions for display formatting

  # Convert indicator type to CSS variant for badge
  defp indicator_type_variant(type) do
    case type do
      :trend -> "secondary"
      :momentum -> "info"
      :volatility -> "warning"
      :volume -> "success"
      :level -> "primary"
      _ -> "secondary"
    end
  end

  # Format parameter name for human readability - cached version
  defp humanize_param_name(name) when is_atom(name) do
    Atom.to_string(name)
    |> humanize_param_name()
  end

  defp humanize_param_name(name) when is_binary(name) do
    name
    |> String.replace("_", " ")
    |> String.split
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_param_name(_), do: "Parameter"

  # Format value for display
  defp humanize_value(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.split
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_value(value), do: to_string(value)
end
