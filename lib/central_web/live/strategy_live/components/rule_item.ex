defmodule CentralWeb.StrategyLive.Components.RuleItem do
  use Phoenix.LiveComponent

  import CentralWeb.Components.UI.Form
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.UI.Select
  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Icon
  import CentralWeb.Components.UI.ScrollArea

  alias CentralWeb.StrategyLive.Components.IndicatorConfig
  alias Central.Backtest.Indicators.ListIndicator
  alias Central.Backtest.DynamicForm.FormGenerator

  # Cache condition types to avoid repeated calculations
  @condition_labels %{
    "crosses_above" => "Crosses Above",
    "crosses_below" => "Crosses Below",
    "is_above" => "Is Above",
    "is_below" => "Is Below"
  }

  # Cache indicator type labels
  @type_labels %{
    trend: "Trend Indicators",
    momentum: "Momentum Indicators",
    volatility: "Volatility Indicators",
    volume: "Volume Indicators",
    level: "Level Indicators"
  }

  attr :remove_handler, :string, default: "remove_entry_rule"
  attr :id, :string, required: true
  attr :rule_type, :string, values: ["entry", "exit"], required: true
  attr :index, :integer, required: true
  attr :rules_count, :integer, required: true
  attr :form, :any, required: true
  attr :rule, :map, required: true
  attr :target, :any, default: nil

  def render(assigns) do
    ~H"""
    <div id={@id} class="rule-item mb-6">
      <div class="border border-gray-200 bg-white rounded-lg shadow-sm">
        <div class="p-4 relative">
          <%= if @rules_count > 1 do %>
            <.button
              type="button"
              phx-click={@remove_handler}
              phx-value-index={@index}
              variant="ghost"
              size="icon"
              class="absolute top-2 right-2 text-destructive hover:text-destructive/80"
            >
              <.icon name="hero-x-mark" class="h-4 w-4" />
              <p class="sr-only">Remove Rule</p>
            </.button>
          <% end %>

          <div class="flex flex-col gap-5">
            <div class="grid grid-cols-1 gap-4">
              <div>
                <.form_item>
                  <.form_label>Indicator</.form_label>
                  <.form_control>
                    <.select
                      :let={select}
                      id={"indicator-select-#{@rule_type}-#{@index}"}
                      name={@indicator_name}
                      value={@indicator_id_str}
                      selected_label={@indicator_label}
                      placeholder={"Choose a #{@rule_type} indicator"}
                    >
                      <.select_trigger builder={select} class="w-full" />
                      <.select_content builder={select} class="w-full">
                        <.scroll_area>
                          <%= for {type, indicators} <- @grouped_indicators do %>
                            <.select_group>
                              <.select_label>
                                {Map.get(@type_labels, type, to_string(type))}
                              </.select_label>
                              <%= for indicator <- indicators do %>
                                <.select_item
                                  builder={select}
                                  value={to_string(indicator.id)}
                                  label={indicator.name}
                                  event_name="indicator_changed"
                                  rule_type={@rule_type}
                                  index={@index}
                                />
                              <% end %>
                            </.select_group>
                          <% end %>
                        </.scroll_area>
                      </.select_content>
                    </.select>
                  </.form_control>
                </.form_item>

                <!-- Hidden fields for condition and value -->
                <input type="hidden" name={@condition_name} value={@condition || "crosses_above"} />
                <input type="hidden" name={@value_name} value={@value_field || "0"} />
              </div>
            </div>

            <div class="mt-2">
              <.live_component
                module={IndicatorConfig}
                id={"indicator-config-#{@rule_type}-#{@index}"}
                indicator_id={@indicator_id_str}
                params={@params}
                name_prefix={@params_prefix}
              />
            </div>

            <%= if @rule_type == "exit" do %>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2 pt-3 border-t border-gray-100">
                <.form_item>
                  <.form_label>Stop Loss (%)</.form_label>
                  <.form_control>
                    <.input
                      name={"#{@rule_type}_stop_loss_#{@index}"}
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      placeholder="e.g. 2.0"
                      id={"#{@rule_type}_stop_loss_#{@index}"}
                      value={@stop_loss_value}
                    />
                  </.form_control>
                  <.form_message field={@form[:stop_loss]} />
                </.form_item>

                <.form_item>
                  <.form_label>Take Profit (%)</.form_label>
                  <.form_control>
                    <.input
                      name={"#{@rule_type}_take_profit_#{@index}"}
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      placeholder="e.g. 4.0"
                      id={"#{@rule_type}_take_profit_#{@index}"}
                      value={@take_profit_value}
                    />
                  </.form_control>
                  <.form_message field={@form[:take_profit]} />
                </.form_item>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    # Skip update if rule hasn't changed (prevents expensive re-processing)
    if socket.assigns[:rule] == assigns.rule &&
         socket.assigns[:index] == assigns.index &&
         socket.assigns[:rule_type] == assigns.rule_type do
      {:ok, socket}
    else
      # Process rule data once (cached in assigns for render)
      processed_assigns = process_rule_data(assigns)
      {:ok, assign(socket, processed_assigns)}
    end
  end

  # Private functions for processing rule data
  defp process_rule_data(assigns) do
    rule = assigns.rule || %{indicator_id: "sma", value: "0", params: %{}}

    # Get indicator_id_str efficiently
    indicator_id_str = extract_indicator_id(rule)

    # If no indicator is selected, default to sma
    indicator_id_str = if indicator_id_str == "" or is_nil(indicator_id_str), do: "sma", else: indicator_id_str

    # Get condition efficiently
    condition = extract_condition(rule)

    # Get indicator and condition label (used in select components)
    selected_indicator = fetch_selected_indicator(indicator_id_str)
    indicator_label = if selected_indicator, do: selected_indicator.name, else: nil

    # Field names based on rule type and index
    indicator_name = "#{assigns.rule_type}_indicator_#{assigns.index}"
    condition_name = "#{assigns.rule_type}_condition_#{assigns.index}"
    value_name = "#{assigns.rule_type}_value_#{assigns.index}"
    params_prefix = "#{assigns.rule_type}_param_#{assigns.index}"

    # For exit rules, get stop loss and take profit values
    stop_loss_value = extract_stop_loss(rule)
    take_profit_value = extract_take_profit(rule)

    # Get value field and params
    value_field = extract_value(rule)
    params = extract_params(rule)

    # Get grouped indicators once
    grouped_indicators = ListIndicator.group_indicators_by_type()

    # Find condition label
    condition_label = Map.get(@condition_labels, condition)

    # Return processed assigns
    assigns
    |> Map.put(:indicator_id_str, indicator_id_str)
    |> Map.put(:condition, condition)
    |> Map.put(:value_field, value_field)
    |> Map.put(:params, params)
    |> Map.put(:grouped_indicators, grouped_indicators)
    |> Map.put(:type_labels, @type_labels)
    |> Map.put(:indicator_label, indicator_label)
    |> Map.put(:condition_label, condition_label)
    |> Map.put(:indicator_name, indicator_name)
    |> Map.put(:condition_name, condition_name)
    |> Map.put(:value_name, value_name)
    |> Map.put(:params_prefix, params_prefix)
    |> Map.put(:stop_loss_value, stop_loss_value)
    |> Map.put(:take_profit_value, take_profit_value)
    |> Map.put(:condition_labels, @condition_labels)
  end

  # Helper functions for safe data extraction from rules

  defp extract_indicator_id(rule) do
    case rule do
      %Central.Backtest.DynamicForm.Rule{} = r ->
        case r.indicator_id do
          nil -> ""
          id when is_atom(id) -> Atom.to_string(id)
          id when is_binary(id) -> id
          id -> to_string(id)
        end

      _ ->
        case rule[:indicator_id] do
          nil -> ""
          id when is_atom(id) -> Atom.to_string(id)
          id when is_binary(id) -> id
          id -> to_string(id)
        end
    end
  end

  defp extract_condition(rule) do
    case rule do
      %Central.Backtest.DynamicForm.Rule{} = r -> r.condition
      _ -> rule[:condition]
    end
  end

  defp extract_stop_loss(rule) do
    case rule do
      %Central.Backtest.DynamicForm.Rule{} = r -> r.stop_loss || "0.02"
      _ -> Map.get(rule, :stop_loss, "0.02")
    end
  end

  defp extract_take_profit(rule) do
    case rule do
      %Central.Backtest.DynamicForm.Rule{} = r -> r.take_profit || "0.04"
      _ -> Map.get(rule, :take_profit, "0.04")
    end
  end

  defp extract_value(rule) do
    case rule do
      %Central.Backtest.DynamicForm.Rule{} = r -> r.value
      _ -> rule[:value]
    end
  end

  defp extract_params(rule) do
    case rule do
      %Central.Backtest.DynamicForm.Rule{} = r -> r.params || %{}
      _ -> rule[:params] || %{}
    end
  end

  # Fetch indicator data (cached when possible)
  defp fetch_selected_indicator(indicator_id_str) when indicator_id_str == "", do: nil
  defp fetch_selected_indicator(indicator_id_str) when indicator_id_str == "nil", do: nil

  defp fetch_selected_indicator(indicator_id_str) do
    FormGenerator.generate_indicator_form(indicator_id_str)
  end
end
