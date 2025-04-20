defmodule CentralWeb.StrategyLive.Components.TradingForm do
  use Phoenix.LiveComponent

  import CentralWeb.Components.UI.Form
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.UI.Select
  import CentralWeb.Components.UI.ScrollArea

  # Cache timeframe options
  @timeframe_labels %{
    "1m" => "1 Minute",
    "5m" => "5 Minutes",
    "15m" => "15 Minutes",
    "30m" => "30 Minutes",
    "1h" => "1 Hour",
    "4h" => "4 Hours",
    "1d" => "1 Day",
    "1w" => "1 Week"
  }

  # Cache symbol options
  @symbol_labels %{
    "BTCUSDT" => "BTC/USDT"
  }

  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <.form_item>
          <.form_label>Timeframe</.form_label>
          <.select :let={select} field={@form[:timeframe]} placeholder="Choose a timeframe">
            <.select_trigger builder={select} class="w-full" />
            <.select_content builder={select} class="w-full">
              <.scroll_area>
                <.select_group>
                  <.select_label>Timeframes</.select_label>
                  <%= for {timeframe_id, timeframe_name} <- sort_timeframes(@timeframe_labels) do %>
                    <.select_item
                      builder={select}
                      value={timeframe_id}
                      label={timeframe_name}
                      event_name="update_trading_form"
                    />
                  <% end %>
                </.select_group>
              </.scroll_area>
            </.select_content>
          </.select>
          <.form_message field={@form[:timeframe]} />
        </.form_item>

        <.form_item>
          <.form_label>Symbol</.form_label>
          <.select
            :let={select}
            field={@form[:symbol]}
            id="symbol-select"
            placeholder="Choose a trading pair"
          >
            <.select_trigger builder={select} class="w-full" />
            <.select_content builder={select} class="w-full">
              <.scroll_area>
                <.select_group>
                  <.select_label>Symbols</.select_label>
                  <%= for {symbol_id, symbol_name} <- sort_symbols(@symbol_labels) do %>
                    <.select_item
                      builder={select}
                      value={symbol_id}
                      label={symbol_name}
                      event_name="update_trading_form"
                    />
                  <% end %>
                </.select_group>
              </.scroll_area>
            </.select_content>
          </.select>
          <.form_message field={@form[:symbol]} />
        </.form_item>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <.form_item>
          <.form_label>Risk per Trade (%)</.form_label>
          <.input
            field={@form[:risk_per_trade]}
            type="number"
            step="0.01"
            min="0"
            max="100"
            placeholder="e.g. 2.0"
          />
          <.form_message field={@form[:risk_per_trade]} />
        </.form_item>

        <.form_item>
          <.form_label>Max Position Size (%)</.form_label>
          <.input
            field={@form[:max_position_size]}
            type="number"
            step="0.01"
            min="0"
            max="100"
            placeholder="e.g. 5.0"
          />
          <.form_message field={@form[:max_position_size]} />
        </.form_item>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    assigns = assigns
    |> Map.put(:timeframe_labels, @timeframe_labels)
    |> Map.put(:symbol_labels, @symbol_labels)

    {:ok, assign(socket, assigns)}
  end

  # Helper function to sort timeframes by time unit magnitude
  defp sort_timeframes(timeframes) do
    # Define the order of time units
    timeframe_order = %{
      "1m" => 1,
      "5m" => 2,
      "15m" => 3,
      "30m" => 4,
      "1h" => 5,
      "4h" => 6,
      "1d" => 7,
      "1w" => 8
    }

    # Sort by the predefined order
    Enum.sort_by(timeframes, fn {id, _name} ->
      Map.get(timeframe_order, id, 999) # Default high value for unknown timeframes
    end)
  end

  defp sort_symbols(symbols) do
    # Define the order of symbols
    symbol_order = %{
      "BTCUSDT" => 1
    }

    # Sort by the predefined order
    Enum.sort_by(symbols, fn {id, _name} ->
      Map.get(symbol_order, id, 999) # Default high value for unknown symbols
    end)
  end
end
