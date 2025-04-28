defmodule CentralWeb.StrategyLive.Components.JsonConfigForm do
  use Phoenix.LiveComponent

  import CentralWeb.Components.UI.Form
  import CentralWeb.Components.UI.Textarea

  # Add an example JSON template
  @example_json_template """
  {
    "name": "Example Strategy",
    "description": "A simple example trading strategy",
    "config": {
      "timeframe": "1h",
      "symbol": "BTCUSDT",
      "risk_per_trade": "0.02",
      "max_position_size": "5"
    },
    "entry_rules": {
      "conditions": [
        {
          "indicator": "rsi",
          "params": {
            "period": 14,
            "price_key": "close"
          },
          "comparison": "crosses_below",
          "value": "30"
        }
      ]
    },
    "exit_rules": {
      "conditions": [
        {
          "indicator": "rsi",
          "params": {
            "period": 14,
            "price_key": "close"
          },
          "comparison": "crosses_above",
          "value": "70",
          "stop_loss": "0.02",
          "take_profit": "0.04"
        }
      ]
    }
  }
  """

  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4">
      <div class="mb-4">
        <h2 class="font-bold text-foreground">JSON Configuration</h2>
      </div>

      <input
        type="hidden"
        name="creation_method"
        value="json"
        phx-click="set_json_mode"
        phx-target={@myself}
      />
      
    <!-- Add hidden fields to satisfy form validation -->
      <input type="hidden" name="name" value="JSON Strategy" />
      <input type="hidden" name="description" value="Created using JSON mode" />
      <input type="hidden" name="timeframe" value="1h" />
      <input type="hidden" name="symbol" value="BTCUSDT" />
      <input type="hidden" name="risk_per_trade" value="0.02" />
      <input type="hidden" name="max_position_size" value="5" />
      
    <!-- Add a pre-validation field to indicate if JSON is valid -->
      <input
        type="hidden"
        name="json_is_valid"
        value={if @json_parse_error, do: "false", else: "true"}
      />

      <div
        :if={@json_parse_error}
        class="bg-destructive/10 border-l-4 border-destructive text-destructive p-4 mb-4"
        role="alert"
      >
        <p class="font-bold">JSON Error</p>
        <p>{@json_parse_error}</p>
        <p class="mt-2 text-sm">Please fix the JSON error before submitting.</p>
      </div>

      <.form_item>
        <.form_label>Strategy JSON</.form_label>
        <.textarea
          id="json-config-input"
          name="json_config"
          value={@json_config_input}
          phx-change="update_json_input"
          phx-target={@myself}
          phx-debounce="500"
          class="h-96 font-mono text-sm"
        />
        <.form_message :if={@json_parse_error} class="text-destructive">
          {@json_parse_error}
        </.form_message>
        <.form_description>
          Define the complete strategy configuration using JSON.
          <span class="font-semibold">
            When saving the strategy, this JSON will be used instead of the form fields.
          </span>
        </.form_description>
      </.form_item>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, json_parse_error: nil)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:json_config_input, fn -> @example_json_template end)
      |> assign_new(:json_parse_error, fn -> nil end)
      |> assign_new(:parent, fn -> nil end)

    {:ok, socket}
  end

  def handle_event("update_json_input", params, socket) do
    # Get the JSON string, handling both direct value format and form data format
    json_string =
      cond do
        # Handle direct value format from some events
        Map.has_key?(params, "value") ->
          params["value"]

        # Handle form data format (common with phx-change)
        Map.has_key?(params, "json_config") ->
          params["json_config"]

        # Fallback for unexpected formats
        true ->
          socket.assigns.json_config_input
      end

    # Process the JSON string
    {json_parse_error, parsed_json} =
      case Jason.decode(json_string) do
        {:ok, parsed} ->
          normalized_json = normalize_json_values(parsed)

          # Check if we normalized anything, and if so, re-encode to update the form
          if normalized_json != parsed do
            case Jason.encode(normalized_json, pretty: true) do
              {:ok, normalized_string} ->
                # Use the normalized JSON string instead
                _json_string = normalized_string

              _ ->
                # Keep original if encoding fails
                nil
            end
          end

          {nil, normalized_json}

        {:error, %Jason.DecodeError{position: pos, data: data, token: token}} ->
          error_message =
            "JSON parse error at position #{pos}: unexpected token \"#{token}\" in \"#{String.slice(data, max(0, pos - 10), 20)}\""

          {error_message, nil}
      end

    # Update our local state
    socket = assign(socket, json_config_input: json_string, json_parse_error: json_parse_error)

    # Notify the parent component of the change if it exists
    if socket.assigns[:parent] do
      send(
        socket.assigns.parent,
        {:json_config_updated,
         %{
           input: json_string,
           error: json_parse_error,
           parsed: parsed_json
         }}
      )
    end

    {:noreply, socket}
  end

  def handle_event("set_json_mode", _params, socket) do
    # Notify the parent component that JSON mode is being used
    if socket.assigns[:parent] do
      send(socket.assigns.parent, {:set_creation_method, "json"})
    end

    {:noreply, socket}
  end

  # Helper function to normalize JSON values
  defp normalize_json_values(json) when is_map(json) do
    # Handle special case for entry and exit rules
    json =
      cond do
        # If this is an entry_rules or exit_rules object
        Map.has_key?(json, "entry_rules") ->
          entry_rules = get_in(json, ["entry_rules", "conditions"]) || []
          updated_entry_rules = Enum.map(entry_rules, &normalize_condition/1)
          put_in(json, ["entry_rules", "conditions"], updated_entry_rules)

        # If this is an exit_rules object
        Map.has_key?(json, "exit_rules") ->
          exit_rules = get_in(json, ["exit_rules", "conditions"]) || []
          updated_exit_rules = Enum.map(exit_rules, &normalize_condition/1)
          put_in(json, ["exit_rules", "conditions"], updated_exit_rules)

        # For other map objects, process all key/values
        true ->
          json
          |> Enum.map(fn {k, v} -> {k, normalize_json_values(v)} end)
          |> Map.new()
      end

    json
  end

  defp normalize_json_values(json) when is_list(json) do
    Enum.map(json, &normalize_json_values/1)
  end

  # Replace null with "0"
  defp normalize_json_values(value) when is_nil(value), do: "0"
  defp normalize_json_values(value), do: value

  # Helper to normalize conditions specifically
  defp normalize_condition(condition) when is_map(condition) do
    # Make sure we have the expected keys
    condition =
      if Map.has_key?(condition, "comparison") && Map.has_key?(condition, "indicator") do
        # Ensure value exists and is not null
        Map.put_new_lazy(condition, "value", fn -> "0" end)
        |> Map.update("value", "0", fn
          nil -> "0"
          val -> val
        end)
      else
        condition
      end

    # Recursively normalize all values in the condition
    Enum.map(condition, fn {k, v} -> {k, normalize_json_values(v)} end) |> Map.new()
  end

  defp normalize_condition(other), do: other
end
