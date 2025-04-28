defmodule CentralWeb.Components.UI.DataTable do
  @moduledoc """
  Advanced data table component inspired by shadcn/ui's data table.
  Built on top of the basic Table component and adds features like:
  - Pagination
  - Sorting
  - Row selection
  - Specialized cell formatting
  - Responsive design
  - Row numbering

  ## Examples

  Basic usage:
  ```heex
  <.data_table
    id="users-table"
    rows={@users}
    row_id={fn user -> user.id end}
  >
    <:col :let={user} field={:name} label="Name">
      <%= user.name %>
    </:col>
    <:col :let={user} field={:email} label="Email">
      <%= user.email %>
    </:col>
  </.data_table>
  ```

  With pagination, sorting, and row selection:
  ```heex
  <.data_table
    id="users-table"
    rows={@users}
    row_id={fn user -> user.id end}
    page={@page}
    page_size={10}
    total_entries={@total_entries}
    on_page_change="page_changed"
    sort_field={@sort_field}
    sort_direction={@sort_direction}
    on_sort="sort"
    selectable
    selected_rows={@selected_rows}
    on_select="select_row"
  >
    <:col :let={user} field={:name} label="Name" sortable>
      <%= user.name %>
    </:col>
    <:col :let={user} field={:email} label="Email" sortable>
      <%= user.email %>
    </:col>
  </.data_table>
  ```

  With row numbering and specialized columns:
  ```heex
  <.data_table
    id="transactions-table"
    rows={@transactions}
    row_id={fn tx -> tx.id end}
    row_numbers
  >
    <:col :let={tx} field={:date} label="Date">
      <%= TableFormatters.format_datetime(tx.date) %>
    </:col>
    <:col :let={tx} field={:amount} label="Amount" numeric>
      <%= TableFormatters.format_currency(tx.amount) %>
    </:col>
    <:col :let={tx} field={:profit} label="Profit" numeric pnl>
      <span class={TableFormatters.pnl_class(tx.profit)}>
        <%= TableFormatters.format_currency(tx.profit) %>
      </span>
    </:col>
  </.data_table>
  """
  use CentralWeb.Component
  import CentralWeb.Components.UI.Table, except: [table_cell: 1]
  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Checkbox
  import CentralWeb.Components.UI.Icon

  alias Phoenix.LiveView.JS

  @doc """
  Renders a data table with advanced features.

  ## Examples

      <.data_table
        id="payments"
        rows={@payments}
        row_id={fn payment -> payment.id end}
        page={@page}
        page_size={10}
        total_entries={@total_entries}
        on_page_change="page_changed"
        selectable
      >
        <:col :let={payment} field={:status} label="Status" sortable>
          <div class="flex items-center gap-2">
            <div class="h-2 w-2 rounded-full bg-green-500"></div>
            <span>Completed</span>
          </div>
        </:col>
        <:col :let={payment} field={:email} label="Email">
          user@example.com
        </:col>
        <:col :let={payment} field={:amount} label="Amount" sortable numeric>
          $99.99
        </:col>
        <:actions :let={payment}>
          <div class="text-right">
            <.dropdown_menu id="payment-menu-123">
              <.dropdown_menu_trigger>
                <.button variant="ghost" size="icon">
                  <.icon name="hero-ellipsis-vertical" class="h-4 w-4" />
                </.button>
              </.dropdown_menu_trigger>
              <.dropdown_menu_content>
                <.dropdown_menu_item phx-click="view" phx-value-id="123">
                  View payment
                </.dropdown_menu_item>
                <.dropdown_menu_item phx-click="edit" phx-value-id="123">
                  Edit
                </.dropdown_menu_item>
              </.dropdown_menu_content>
            </.dropdown_menu>
          </div>
        </:actions>
      </.data_table>
  """
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
  attr :selectable, :boolean, default: false
  attr :selected_rows, :list, default: []
  attr :on_select, :string, default: nil

  attr :phx_value_keys, :map,
    default: %{},
    doc: "Map of extra values to include in select/sort/page events"

  attr :class, :string, default: nil
  attr :row_class, :string, default: nil
  attr :row_numbers, :boolean, default: false, doc: "Show row numbers starting from 1"
  attr :compact, :boolean, default: false, doc: "Use compact styling with reduced padding"
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
        <%= if Enum.empty?(@rows) and @empty_state != [] do %>
          {render_slot(@empty_state)}
        <% else %>
          <%= if Enum.empty?(@rows) do %>
            <div class="bg-muted/20 rounded-md p-8 text-center text-muted-foreground">
              {@empty_message}
            </div>
          <% else %>
            <div class="rounded-md border-2 p-2">
              <.table>
                <.table_header>
                  <.table_row>
                    <%= if @selectable do %>
                      <.table_head class="w-[42px] px-0 text-center">
                        <div class="flex items-center justify-center">
                          <%!-- Calculate if all rows on the current page are selected --%>
                          <% current_page_row_ids = Enum.map(@rows, @row_id) %>
                          <% all_on_page_selected? =
                            !Enum.empty?(current_page_row_ids) &&
                              Enum.all?(current_page_row_ids, fn id -> id in @selected_rows end) %>
                          <.checkbox
                            id={"#{@id}-checkbox-select-all"}
                            value={all_on_page_selected?}
                            phx-click={
                              @on_select &&
                                JS.push(@on_select,
                                  value: Map.merge(@phx_value_keys, %{select_all: "toggle"})
                                )
                            }
                            class="h-4 w-4"
                          />
                        </div>
                      </.table_head>
                    <% end %>

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
                      class={classes([@row_class, @compact && "h-8"])}
                      data-state={if row_id in @selected_rows, do: "selected"}
                    >
                      <%= if @selectable do %>
                        <.table_cell class={
                          classes(["w-[42px] px-0 text-center", @compact && "py-1"])
                        }>
                          <div class="flex items-center justify-center">
                            <.checkbox
                              id={"#{@id}-checkbox-select-#{row_id}"}
                              value={row_id in @selected_rows}
                              phx-click={
                                @on_select &&
                                  JS.push(@on_select,
                                    value: Map.merge(@phx_value_keys, %{select: row_id})
                                  )
                              }
                              class="h-4 w-4"
                            />
                          </div>
                        </.table_cell>
                      <% end %>

                      <%= if @row_numbers do %>
                        <.table_cell class={
                          classes([
                            "text-center text-sm text-muted-foreground w-[40px]",
                            @sticky_first_col && "sticky left-0 z-10 bg-background",
                            @compact && "p-1"
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
                                "sticky left-0 z-10 bg-background",
                              @compact && "p-1"
                            ])
                          }
                        >
                          {render_slot(col, row)}
                        </.table_cell>
                      <% end %>
                      <%= if @actions != [] do %>
                        <.table_cell class={@compact && "p-1"}>
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
                <%= if @selectable do %>
                  {length(@selected_rows)} of {length(@rows)} row(s) selected.
                <% else %>
                  <%= if @page_size do %>
                    Showing {min((@page - 1) * @page_size + 1, @total_entries)} to {min(
                      @page * @page_size,
                      @total_entries
                    )} of {@total_entries} entries
                  <% end %>
                <% end %>
              </div>

              <%= if @on_page_change && @total_entries > @page_size do %>
                <div class="flex items-center space-x-2">
                  <.button
                    variant="outline"
                    size="sm"
                    phx-click={
                      @on_page_change &&
                        JS.push(@on_page_change,
                          value: Map.merge(@phx_value_keys, %{page: @page - 1})
                        )
                    }
                    disabled={@page <= 1}
                  >
                    Previous
                  </.button>
                  <div class="text-sm">
                    Page {@page} of {ceil(@total_entries / @page_size)}
                  </div>
                  <.button
                    variant="outline"
                    size="sm"
                    phx-click={
                      @on_page_change &&
                        JS.push(@on_page_change,
                          value: Map.merge(@phx_value_keys, %{page: @page + 1})
                        )
                    }
                    disabled={@page >= ceil(@total_entries / @page_size)}
                  >
                    Next
                  </.button>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  def table_cell(assigns) do
    assigns =
      assigns
      |> assign_new(:numeric, fn -> false end)
      |> assign_new(:pnl, fn -> false end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:rest, fn -> %{} end)

    ~H"""
    <td
      class={
        classes([
          "py-4 px-2 align-middle [&:has([role=checkbox])]:pr-0",
          @numeric && "text-right tabular-nums",
          @pnl && "font-medium",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </td>
    """
  end
end
