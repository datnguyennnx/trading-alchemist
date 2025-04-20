defmodule Central.Backtest.DynamicForm.FormGenerator do
  @moduledoc """
  Generates dynamic form configurations based on indicator metadata.

  This module serves as a bridge between the indicator metadata system
  and the LiveView UI, providing structured form configurations for
  different indicator types.
  """

  alias Central.Backtest.Indicators
  alias Central.Backtest.Indicators.ListIndicator

  @doc """
  Generate form configuration for an indicator

  ## Parameters
    - indicator_id: The atom or string identifier of the indicator

  ## Returns
    - Map with form configuration including id, name, description, and fields
    - nil if indicator not found
  """
  def generate_indicator_form(indicator_id) when is_binary(indicator_id) or is_atom(indicator_id) do
    # Use the optimized function from Indicators module to get pre-processed form data
    indicator = Indicators.get_indicator_for_form(indicator_id)

    if indicator do
      generate_form_from_indicator(indicator)
    else
      # Fallback to direct lookup if the optimized function doesn't find it
      direct_indicator = ListIndicator.get_indicator(indicator_id)
      if direct_indicator, do: generate_form_from_indicator(direct_indicator), else: nil
    end
  end

  def generate_indicator_form(_), do: nil

  @doc """
  Get available conditions for rule configuration
  """
  def available_conditions do
    [
      %{id: "crosses_above", name: "Crosses Above"},
      %{id: "crosses_below", name: "Crosses Below"},
      %{id: "is_above", name: "Is Above"},
      %{id: "is_below", name: "Is Below"}
    ]
  end

  @doc """
  Generate a default rule for an indicator.
  Uses optimized functions to efficiently get default parameters.
  """
  def generate_default_rule(indicator_id) do
    # Use the optimized default params function for better performance
    default_params = Indicators.get_default_params(indicator_id)

    if default_params != %{} do
      # When parameters are available, use them
      %{
        indicator_id: indicator_id,
        condition: "crosses_above",
        value: "0",
        params: default_params
      }
    else
      # Create a minimal default rule when no indicator or params found
      %{
        indicator_id: indicator_id || nil,
        condition: "crosses_above",
        value: "0",
        params: %{}
      }
    end
  end

  # Private helpers

  defp generate_form_from_indicator(indicator) do
    %{
      id: indicator.id,
      name: indicator.name,
      description: indicator.description,
      type: indicator.type,
      fields: generate_fields_from_params(indicator.params || [])
    }
  end

  defp generate_fields_from_params(params) do
    Enum.map(params, fn param ->
      generate_field(param)
    end)
  end

  defp generate_field(%{type: :number} = param) do
    %{
      type: :number,
      name: param.name,
      label: param.label || humanize_param_name(param.name),
      default: param.default,
      min: Map.get(param, :min),
      max: Map.get(param, :max),
      step: Map.get(param, :step, 1)
    }
  end

  defp generate_field(%{type: :select} = param) do
    %{
      type: :select,
      name: param.name,
      label: param.label || humanize_param_name(param.name),
      default: param.default,
      options: param.options
    }
  end

  defp generate_field(%{type: :text} = param) do
    %{
      type: :text,
      name: param.name,
      label: param.label || humanize_param_name(param.name),
      default: param.default
    }
  end

  defp generate_field(param) do
    # Default fallback for unknown types
    %{
      type: :text,
      name: param.name,
      label: Map.get(param, :label, humanize_param_name(param.name)),
      default: Map.get(param, :default, "")
    }
  end

  # Helper function to humanize parameter names for better display
  defp humanize_param_name(name) when is_atom(name) do
    Atom.to_string(name)
    |> humanize_param_name()
  end

  defp humanize_param_name(name) when is_binary(name) do
    name
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_param_name(_), do: "Parameter"
end
