defmodule Central.Backtest.DynamicForm.FormTransformer do
  @moduledoc """
  Transforms between form data and domain models for strategy rules.

  This module handles the bidirectional conversion between:
  1. Form data (string-keyed maps with field names like "entry_indicator_0")
  2. Domain model structs (Rule structs with atom keys)

  It's used by the strategy live views to prepare data for forms and process
  form submissions into properly structured data for storage.
  """

  alias Central.Backtest.DynamicForm.Rule

  @doc """
  Converts a list of Rule structs to form data for the LiveView.

  ## Parameters
    - rules: List of Rule structs
    - rule_type: String "entry" or "exit" to determine field naming

  ## Returns
    - Map with form field keys like "entry_indicator_0", "entry_params_0", etc.
  """
  def rules_to_form(rules, rule_type) when is_list(rules) and rule_type in ["entry", "exit"] do
    rules
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {rule, index}, acc ->
      Map.merge(acc, rule_to_form(rule, rule_type, index))
    end)
  end

  @doc """
  Converts a single Rule struct to form data.

  ## Parameters
    - rule: Rule struct
    - rule_type: String "entry" or "exit" to determine field naming
    - index: Integer index for the rule (used in field naming)

  ## Returns
    - Map with form field keys for this specific rule
  """
  def rule_to_form(nil, rule_type, index) when rule_type in ["entry", "exit"] do
    # Handle nil rule by returning empty fields
    %{
      "#{rule_type}_indicator_#{index}" => nil,
      "#{rule_type}_condition_#{index}" => nil,
      "#{rule_type}_value_#{index}" => nil,
      "#{rule_type}_params_#{index}" => %{}
    }
  end

  def rule_to_form(%Rule{} = rule, rule_type, index) when rule_type in ["entry", "exit"] do
    # Base fields for both entry and exit rules
    form_data = %{
      "#{rule_type}_indicator_#{index}" => rule.indicator_id,
      "#{rule_type}_condition_#{index}" => rule.condition,
      "#{rule_type}_value_#{index}" => rule.value,
      "#{rule_type}_params_#{index}" => stringified_params(rule.params)
    }

    # Add stop_loss and take_profit for exit rules
    if rule_type == "exit" do
      form_data
      |> Map.put("stop_loss_#{index}", rule.stop_loss || "0.02")
      |> Map.put("take_profit_#{index}", rule.take_profit || "0.04")
    else
      form_data
    end
  end

  @doc """
  Extracts rules from form data.

  ## Parameters
    - form_data: Map with form field values
    - rule_type: String "entry" or "exit" to determine which fields to look for

  ## Returns
    - List of Rule structs
  """
  def form_to_rules(form_data, rule_type) when rule_type in ["entry", "exit"] do
    # Find all indices used in the form for this rule type
    indices =
      form_data
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "#{rule_type}_indicator_") end)
      |> Enum.map(fn {k, _} ->
        String.replace(k, "#{rule_type}_indicator_", "") |> String.to_integer()
      end)
      |> Enum.sort()

    # For each index, extract the rule data and create a Rule struct
    Enum.map(indices, fn index ->
      indicator_id = Map.get(form_data, "#{rule_type}_indicator_#{index}")
      condition = Map.get(form_data, "#{rule_type}_condition_#{index}")
      value = Map.get(form_data, "#{rule_type}_value_#{index}")
      params = Map.get(form_data, "#{rule_type}_params_#{index}", %{})

      # Skip rules with missing required fields
      if indicator_id && condition && value do
        rule_attrs = %{
          id: "#{rule_type}_#{index}",
          indicator_id: indicator_id,
          condition: condition,
          value: value,
          params: atomized_params(params)
        }

        # Add stop_loss and take_profit for exit rules
        rule_attrs =
          if rule_type == "exit" do
            rule_attrs
            |> Map.put(:stop_loss, Map.get(form_data, "stop_loss_#{index}"))
            |> Map.put(:take_profit, Map.get(form_data, "take_profit_#{index}"))
          else
            rule_attrs
          end

        Rule.new(rule_attrs)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1) # Remove nil entries (rules with missing fields)
  end

  @doc """
  Builds rule list in the format expected by the strategy schema.

  ## Parameters
    - rules: List of Rule structs

  ## Returns
    - List of maps in the format expected by the database schema
  """
  def rules_to_conditions(rules) when is_list(rules) do
    Enum.map(rules, fn rule ->
      condition = %{
        "indicator" => rule.indicator_id,
        "comparison" => rule.condition,
        "value" => rule.value,
        "params" => rule.params
      }

      # Add stop_loss and take_profit if they exist
      condition =
        if rule.stop_loss || rule.take_profit do
          condition
          |> Map.put("stop_loss", rule.stop_loss)
          |> Map.put("take_profit", rule.take_profit)
        else
          condition
        end

      condition
    end)
  end

  @doc """
  Converts conditions from the database format to Rule structs.

  ## Parameters
    - conditions: List of condition maps from the database
    - rule_type: String "entry" or "exit" for ID generation

  ## Returns
    - List of Rule structs
  """
  def conditions_to_rules(nil, rule_type), do: [Rule.new(%{id: "#{rule_type}_0"})]
  def conditions_to_rules(conditions, rule_type) when is_list(conditions) do
    conditions
    |> Enum.with_index()
    |> Enum.map(fn {condition, index} ->
      rule_attrs = %{
        id: "#{rule_type}_#{index}",
        indicator_id: Map.get(condition, "indicator"),
        condition: Map.get(condition, "comparison"),
        value: Map.get(condition, "value"),
        params: Map.get(condition, "params", %{})
      }

      # Add stop_loss and take_profit for exit rules
      rule_attrs =
        if rule_type == "exit" do
          rule_attrs
          |> Map.put(:stop_loss, Map.get(condition, "stop_loss"))
          |> Map.put(:take_profit, Map.get(condition, "take_profit"))
        else
          rule_attrs
        end

      Rule.new(rule_attrs)
    end)
  end

  # Private helper functions

  # Convert atom keys to string keys for form data
  defp stringified_params(nil), do: %{}
  defp stringified_params(params) when is_map(params) do
    Enum.reduce(params, %{}, fn
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, Atom.to_string(key), value)
      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  # Convert string keys to atom keys for domain models
  defp atomized_params(params) when is_map(params) do
    Enum.reduce(params, %{}, fn
      {key, value}, acc when is_binary(key) ->
        Map.put(acc, String.to_atom(key), value)
      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end
end
