defmodule CentralWeb.StrategyLive.IndexLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext
  alias Central.Backtest.Indicators

  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.Button

  def mount(_params, _session, socket) do
    strategies = list_strategies()

    {:ok,
     socket
     |> assign(:strategies, strategies)
     |> assign(:indicators, Indicators.list_indicators())
     |> assign(:page_title, "Trading Strategies")}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Trading Strategies</h1>
        <.link navigate={~p"/strategies/new"}>
          <.button>Create Strategy</.button>
        </.link>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= if Enum.empty?(@strategies) do %>
          <div class="col-span-full">
            <.card>
              <.card_header>
                <.card_title>No Strategies Found</.card_title>
                <.card_description>
                  Get started by creating your first trading strategy
                </.card_description>
              </.card_header>
              <.card_content>
                <p class="text-muted-foreground">
                  Define entry and exit rules, set risk parameters, and run backtests to evaluate performance.
                </p>
              </.card_content>
              <.card_footer>
                <.link navigate={~p"/strategies/new"}>
                  <.button class="w-full">Create Your First Strategy</.button>
                </.link>
              </.card_footer>
            </.card>
          </div>
        <% else %>
          <%= for strategy <- @strategies do %>
            <.card>
              <.card_header>
                <.card_title>{strategy.name}</.card_title>
                <.card_description>{truncate_description(strategy.description)}</.card_description>
              </.card_header>
              <.card_content>
                <div class="space-y-4">
                  <div class="flex justify-between">
                    <p class="text-muted-foreground">Symbol:</p>
                    <p class="font-medium">{strategy.config["symbol"]}</p>
                  </div>
                  <div class="flex justify-between">
                    <p class="text-muted-foreground">Timeframe:</p>
                    <p class="font-medium">{strategy.config["timeframe"]}</p>
                  </div>
                  <div class="flex justify-between">
                    <p class="text-muted-foreground">Rules:</p>
                    <p class="font-medium">
                      {count_entry_rules(strategy)} entries, {count_exit_rules(strategy)} exits
                    </p>
                  </div>
                  <div class="flex justify-between">
                    <p class="text-muted-foreground">Indicators:</p>
                    <p class="font-medium">
                      {summary_indicators(strategy, @indicators)}
                    </p>
                  </div>
                </div>
              </.card_content>
              <.card_footer class="flex justify-between">
                <.link navigate={~p"/strategies/#{strategy.id}"}>
                  <.button variant="outline">View</.button>
                </.link>
                <.link navigate={~p"/backtest/#{strategy.id}"}>
                  <.button>Run Backtest</.button>
                </.link>
              </.card_footer>
            </.card>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp list_strategies do
    StrategyContext.list_strategies()
  end

  defp truncate_description(nil), do: "No description provided"

  defp truncate_description(description) do
    if String.length(description) > 100 do
      String.slice(description, 0..97) <> "..."
    else
      description
    end
  end

  defp count_entry_rules(strategy) do
    case strategy.entry_rules do
      %{"conditions" => conditions} when is_list(conditions) -> length(conditions)
      _ -> 0
    end
  end

  defp count_exit_rules(strategy) do
    case strategy.exit_rules do
      %{"conditions" => conditions} when is_list(conditions) -> length(conditions)
      _ -> 0
    end
  end

  defp summary_indicators(strategy, indicators) do
    # Get all unique indicators used in the strategy
    entry_indicators =
      case strategy.entry_rules do
        %{"conditions" => conditions} when is_list(conditions) ->
          Enum.map(conditions, & &1["indicator"])

        _ ->
          []
      end

    exit_indicators =
      case strategy.exit_rules do
        %{"conditions" => conditions} when is_list(conditions) ->
          Enum.map(conditions, & &1["indicator"])

        _ ->
          []
      end

    all_indicators = entry_indicators ++ exit_indicators
    unique_indicators = Enum.uniq(all_indicators)

    case length(unique_indicators) do
      0 ->
        "None"

      1 ->
        display_indicator_name(hd(unique_indicators), indicators)

      2 ->
        "#{display_indicator_name(Enum.at(unique_indicators, 0), indicators)}, #{display_indicator_name(Enum.at(unique_indicators, 1), indicators)}"

      n when n > 2 ->
        "#{n} indicators"
    end
  end

  defp display_indicator_name(indicator_id, indicators) do
    case Enum.find(indicators, fn i -> i.id == indicator_id end) do
      %{id: id} when id in ["sma", "ema", "rsi", "macd"] ->
        String.upcase(id)

      %{id: "bollinger_bands"} ->
        "BB"

      %{name: name} ->
        name

      _ ->
        indicator_id || "Unknown"
    end
  end
end
