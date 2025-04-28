defmodule CentralWeb.StrategyLive.Components.EntryRulesForm do
  use Phoenix.LiveComponent

  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Icon
  alias CentralWeb.StrategyLive.Components.RuleItem

  attr :entry_rules, :list, required: true, doc: "The list of entry rule data maps/structs"
  # Keep form for potential error messages
  attr :form, :any, required: true
  attr :remove_handler, :string, default: "remove_entry_rule"
  attr :id, :string, default: "entry-rules-form"
  attr :target, :any, default: nil

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <div class="flex justify-between items-center mb-4">
        <h2 class="font-bold text-foreground">Trading Entry Rules</h2>
        <.button
          type="button"
          phx-click="add_entry_rule"
          variant="outline"
          size="sm"
          class="bg-background hover:bg-muted"
        >
          <.icon name="hero-plus" class="h-4 w-4 mr-1" /> Add Entry Rule
        </.button>
      </div>

      <%= if Enum.empty?(@entry_rules) do %>
        <div class="bg-info/10 border border-info/20 rounded-lg p-4 text-info text-sm">
          <p class="flex items-center">
            <.icon name="hero-information-circle" class="h-5 w-5 mr-2 text-info" />
            <span>Add an entry rule to define when your strategy should enter a position.</span>
          </p>
        </div>
      <% else %>
        <div class="space-y-5">
          <%= for {rule, index} <- Enum.with_index(@entry_rules) do %>
            <.live_component
              module={RuleItem}
              id={"entry-rule-#{index}"}
              rule_type="entry"
              index={index}
              rules_count={Enum.count(@entry_rules)}
              remove_handler={@remove_handler}
              form={@form}
              rule={rule}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Add update/2 function to optimize rendering
  def update(assigns, socket) do
    # Check if anything important has changed to avoid unnecessary re-renders
    if socket.assigns != %{} &&
         socket.assigns[:entry_rules] == assigns.entry_rules &&
         socket.assigns[:id] == assigns.id do
      {:ok, socket}
    else
      {:ok, assign(socket, assigns)}
    end
  end
end
