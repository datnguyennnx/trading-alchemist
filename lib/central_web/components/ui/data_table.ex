defmodule CentralWeb.Components.UI.DataTable do

  use CentralWeb.Component
  import CentralWeb.Components.UI.Table
  import CentralWeb.Components.UI.Icon
  import CentralWeb.Components.UI.Pagination

  alias Phoenix.LiveView.JS
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, required: true, doc: "Function to extract unique ID from each row"
  attr :page, :integer, default: 1
  attr :page_size, :integer, default: 10
  attr :total_entries, :integer, default: 0
  attr :on_page_change, :string, default: nil
  attr :sort_field, :atom, default: nil
  attr :sort_direction, :atom, default: :asc
  attr :on_sort, :string, default: nil
  attr :phx_value_keys, :map,
    default: %{},
    doc: "Map of extra values to include in sort/page events"

  attr :class, :string, default: nil
  attr :row_class, :string, default: nil
  attr :row_numbers, :boolean, default: false, doc: "Show row numbers starting from 1"
  attr :sticky_first_col, :boolean, default: false, doc: "Make the first column sticky"

  attr :empty_message, :string,
    default: "No data available",
    doc: "Message to show when there are no rows"

  attr :loading, :boolean, default: false, doc: "Show loading state"

  slot :filter, doc: "Optional content for filtering controls placed above the table"
  slot :empty_state, doc: "Custom content for empty state when rows is empty"
  slot :loading_state, doc: "Custom content for loading state"

  slot :col, required: true do
    attr :label, :string, required: true
    attr :field, :atom
    attr :sortable, :boolean
    attr :numeric, :boolean
    attr :pnl, :boolean
    attr :class, :string
    attr :header_class, :string, doc: "Additional classes for the header cell"
    attr :sticky, :boolean, doc: "Make this column sticky (not compatible with row_numbers)"
    attr :width, :string, doc: "Set explicit width of the column (e.g. 'w-20' or 'w-[200px]')"
    attr :min_width, :string, doc: "Set minimum width of the column (e.g. 'min-w-[100px]')"
  end

  slot :actions

  attr :numeric, :boolean, default: false
  attr :pnl, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def data_table(assigns) do
    ~H"""
    <div id={@id} class={classes(["w-full space-y-4", @class])}>
      <%= if @filter != [] do %>
        <div class="mb-4">
          {render_slot(@filter)}
        </div>
      <% end %>

      <%= if @loading and @loading_state != [] do %>
        {render_slot(@loading_state)}
      <% else %>
        <%= if Enum.empty?(@rows) do %>
          <%!-- If rows are empty, render empty state slot if provided, otherwise default message --%>
          <%= if @empty_state != [] do %>
            {render_slot(@empty_state)}
          <% else %>
            <div class="bg-muted/20 rounded-md p-8 text-center text-muted-foreground">
              {@empty_message}
            </div>
          <% end %>
        <% else %>
          <%!-- Rows are not empty, render the table --%>
          <div class="rounded-md border-2">
            <.table>
              <.table_header>
                <.table_row>
                  <%!-- Remove selectable checkbox header --%>

                  <%= if @row_numbers do %>
                    <.table_head class={
                      classes([
                        "w-[40px] text-center",
                        @sticky_first_col && "sticky left-0 z-20 bg-background"
                      ])
                    }>
                      #
                    </.table_head>
                  <% end %>

                  <%= for {col, col_index} <- Enum.with_index(@col) do %>
                    <.table_head
                      class={
                        classes([
                          col[:width],
                          col[:min_width],
                          col[:sticky] && "sticky z-20 bg-background",
                          col[:sticky] && col_index == 0 && "left-0",
                          @sticky_first_col && col_index == 0 && !@row_numbers &&
                            "sticky left-0 z-20 bg-background",
                          col[:header_class]
                        ])
                      }
                      numeric={col[:numeric]}
                    >
                      <%= if col[:sortable] && @on_sort && col[:field] do %>
                        <div
                          class="flex cursor-pointer items-center gap-1"
                          phx-click={@on_sort && JS.push(@on_sort, value: %{field: col[:field]})}
                        >
                          {col.label}
                          <%= if @sort_field == col[:field] do %>
                            <.icon
                              name={
                                (@sort_direction == :asc && "hero-arrow-up-circle") ||
                                  "hero-arrow-down-circle"
                              }
                              class="h-4 w-4"
                            />
                          <% end %>
                        </div>
                      <% else %>
                        {col.label}
                      <% end %>
                    </.table_head>
                  <% end %>
                  <%= if @actions != [] do %>
                    <.table_head class="w-[80px]"></.table_head>
                  <% end %>
                </.table_row>
              </.table_header>
              <.table_body>
                <%= for {row, index} <- Enum.with_index(@rows) do %>
                  <% row_id = @row_id.(row) %>
                  <.table_row
                    id={@id <> "-row-" <> to_string(row_id)}
                    class={classes([@row_class])}
                  >
                    <%= if @row_numbers do %>
                      <.table_cell class={
                        classes([
                          "text-center text-sm text-muted-foreground w-[40px]",
                          @sticky_first_col && "sticky left-0 z-10 bg-background"
                        ])
                      }>
                        {index + 1 + (@page - 1) * @page_size}
                      </.table_cell>
                    <% end %>

                    <%= for {col, col_index} <- Enum.with_index(@col) do %>
                      <.table_cell
                        numeric={col[:numeric]}
                        class={
                          classes([
                            col[:class],
                            col[:width],
                            col[:min_width],
                            col[:sticky] && "sticky z-10 bg-background",
                            col[:sticky] && col_index == 0 && "left-0",
                            @sticky_first_col && col_index == 0 && !@row_numbers &&
                              "sticky left-0 z-10 bg-background"
                          ])
                        }
                      >
                        {render_slot(col, row)}
                      </.table_cell>
                    <% end %>
                    <%= if @actions != [] do %>
                      <.table_cell>
                        {render_slot(@actions, row)}
                      </.table_cell>
                    <% end %>
                  </.table_row>
                <% end %>
              </.table_body>
            </.table>
          </div>

          <div class="flex items-center justify-between px-2">
            <div class="text-sm text-muted-foreground">
              <%!-- Remove selected rows count --%>
              <%= if @page_size do %>
                Showing {min((@page - 1) * @page_size + 1, @total_entries)} to {min(
                  @page * @page_size,
                  @total_entries
                )} of {@total_entries} entries
              <% end %>
            </div>

            <%= if @on_page_change && @total_entries > @page_size do %>
              <div class="flex flex-row items-center space-x-2">
                <p class="w-full text-sm font-medium">
                  Page {@page} of {ceil(@total_entries / @page_size)}
                </p>
                <.pagination>
                  <.pagination_content>
                    <.pagination_item>
                      <.pagination_previous
                        phx-click={unless @page <= 1, do: JS.push(@on_page_change, value: Map.merge(@phx_value_keys, %{page: @page - 1}))}
                        disabled={@page <= 1}
                      />
                    </.pagination_item>
                    <.pagination_item>
                      <.pagination_next
                        phx-click={unless @page >= ceil(@total_entries / @page_size), do: JS.push(@on_page_change, value: Map.merge(@phx_value_keys, %{page: @page + 1}))}
                        disabled={@page >= ceil(@total_entries / @page_size)}
                      />
                    </.pagination_item>
                  </.pagination_content>
                </.pagination>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
