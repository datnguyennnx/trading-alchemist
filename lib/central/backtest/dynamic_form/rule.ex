defmodule Central.Backtest.DynamicForm.Rule do
  @moduledoc """
  Domain model representing a trading rule (entry or exit)
  """

  @enforce_keys [:id]
  defstruct [
    # Unique identifier for the rule
    :id,
    # Atom representing the indicator (e.g., :sma, :rsi)
    :indicator_id,
    # String condition (e.g., "crosses_above")
    :condition,
    # String value (converted to appropriate type when used)
    :value,
    # Map of parameters specific to the indicator
    :params,
    # For exit rules: stop loss percentage
    :stop_loss,
    # For exit rules: take profit percentage
    :take_profit
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          indicator_id: atom() | String.t(),
          condition: String.t(),
          value: String.t() | number(),
          params: map(),
          stop_loss: String.t() | float() | nil,
          take_profit: String.t() | float() | nil
        }

  @doc """
  Creates a new rule with the given attributes
  """
  def new(attrs \\ %{}) do
    # Generate a random ID if not provided
    attrs =
      if Map.has_key?(attrs, :id) || Map.has_key?(attrs, "id"),
        do: attrs,
        else: Map.put(attrs, :id, generate_id())

    struct(__MODULE__, atomize_keys(attrs))
  end

  @doc """
  Validates rule parameters against indicator metadata
  """
  def validate_params(rule, indicator_metadata) do
    validated_params =
      indicator_metadata.params
      |> Enum.reduce(%{}, fn param_spec, acc ->
        param_name = param_spec.name

        provided_value =
          get_in(rule.params, [param_name]) ||
            get_in(rule.params, [to_string(param_name)]) ||
            param_spec.default

        validated_value = validate_param_value(provided_value, param_spec)
        Map.put(acc, param_name, validated_value)
      end)

    %{rule | params: validated_params}
  end

  defp validate_param_value(value, %{type: :number} = spec) do
    num_value =
      case value do
        v when is_binary(v) ->
          case Float.parse(v) do
            {float, _} -> float
            :error -> spec.default
          end

        v when is_number(v) ->
          v

        _ ->
          spec.default
      end

    # Apply min/max constraints
    cond do
      Map.has_key?(spec, :min) && num_value < spec.min -> spec.min
      Map.has_key?(spec, :max) && num_value > spec.max -> spec.max
      true -> num_value
    end
  end

  defp validate_param_value(value, %{type: :select} = spec) do
    string_value = to_string(value)
    string_options = Enum.map(spec.options, &to_string/1)

    if string_value in string_options, do: value, else: spec.default
  end

  defp validate_param_value(value, _spec), do: value

  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  defp atomize_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_binary(key) ->
        key_atom = String.to_atom(key)
        Map.put(acc, key_atom, value)

      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)
    end)
  end
end
