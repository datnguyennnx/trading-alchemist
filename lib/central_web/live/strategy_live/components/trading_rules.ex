defmodule CentralWeb.StrategyLive.Components.TradingRules do
  use CentralWeb, :live_component
  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.Icon
  import CentralWeb.Components.UI.Tooltip
  import CentralWeb.Components.UI.Table

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.card>
        <.card_header>
          <.card_title>Trading Rules</.card_title>
          <.card_description>
            Set of conditions that control entry and exit positions
          </.card_description>
        </.card_header>
        <.card_content class="p-0">
          <!-- Entry Rules Section -->
          <div class="p-4 py-1">
            <div class="flex items-center py-3">
              <.icon name="hero-arrow-up-circle" class="h-5 w-5 text-success mr-2" />
              <p class="font-medium">Entry Rules</p>
            </div>
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head>Indicator</.table_head>
                  <.table_head>Condition</.table_head>
                  <.table_head numeric>Value</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <%= for rule <- get_entry_rules(@strategy) do %>
                  <.table_row>
                    <.table_cell class="font-medium px-2 py-1.5">
                      <p class="font-bold">
                        {format_rule_name(get_indicator_display_name(rule["indicator"], @indicators))}
                      </p>
                    </.table_cell>
                    <.table_cell class="px-2 py-1.5">
                      <p class="underline decoration-dotted">
                        {format_condition(rule["comparison"])}
                      </p>
                    </.table_cell>
                    <.table_cell numeric class="font-medium px-2 py-1.5">
                      {format_value(rule["value"])}
                    </.table_cell>
                  </.table_row>
                <% end %>
                <%= if Enum.empty?(get_entry_rules(@strategy)) do %>
                  <.table_row>
                    <.table_cell class="text-center text-muted-foreground py-4 px-2">
                      No entry rules defined.
                    </.table_cell>
                  </.table_row>
                <% end %>
              </.table_body>
            </.table>
          </div>

    <!-- Exit Rules Section -->
          <div class="p-4 py-1">
            <div class="flex items-center py-3">
              <.icon name="hero-arrow-down-circle" class="h-5 w-5 text-destructive mr-2" />
              <p class="font-medium">Exit Rules</p>
            </div>
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head>Indicator</.table_head>
                  <.table_head>Condition</.table_head>
                  <.table_head>Value</.table_head>
                  <.table_head numeric>SL (%)</.table_head>
                  <.table_head numeric>TP (%)</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <%= for rule <- get_exit_rules(@strategy) do %>
                  <.table_row>
                    <.table_cell class="font-medium px-2 py-1.5">
                      <p class="font-bold">
                        {format_rule_name(get_indicator_display_name(rule["indicator"], @indicators))}
                      </p>
                    </.table_cell>
                    <.table_cell class="px-2 py-1.5">
                      <p class="underline decoration-dotted">
                        {format_condition(rule["comparison"])}
                      </p>
                    </.table_cell>
                    <.table_cell class="font-medium px-2 py-1.5">
                      {format_value(rule["value"])}
                    </.table_cell>
                    <.table_cell numeric class="font-medium text-destructive px-2 py-1.5">
                      {if rule["stop_loss"], do: rule["stop_loss"], else: "-"}
                    </.table_cell>
                    <.table_cell numeric class="font-medium text-success px-2 py-1.5">
                      {if rule["take_profit"], do: rule["take_profit"], else: "-"}
                    </.table_cell>
                  </.table_row>
                <% end %>
                <%= if Enum.empty?(get_exit_rules(@strategy)) do %>
                  <.table_row>
                    <.table_cell class="text-center text-muted-foreground py-4 px-2">
                      No exit rules defined.
                    </.table_cell>
                  </.table_row>
                <% end %>
              </.table_body>
            </.table>
          </div>
        </.card_content>
      </.card>
    </div>
    """
  end

  # Helper functions for rule display
  defp get_entry_rules(strategy), do: Map.get(strategy.entry_rules || %{}, "conditions", [])
  defp get_exit_rules(strategy), do: Map.get(strategy.exit_rules || %{}, "conditions", [])

  defp get_indicator_display_name(indicator_id, indicators) do
    indicator = Enum.find(indicators, &(&1.id == indicator_id))
    (indicator && indicator.name) || format_rule_name(indicator_id)
  end

  defp format_condition(condition) when is_binary(condition), do: condition
  defp format_condition(_), do: ""

  defp format_value(nil), do: ""
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(_), do: ""

  defp format_rule_name(name) when is_binary(name) do
    name
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_rule_name(name), do: to_string(name)
end
