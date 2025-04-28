defmodule CentralWeb.Components.DateTimePicker do
  use CentralWeb.Component

  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.UI.Select
  import CentralWeb.Components.UI.Label
  import CentralWeb.Components.UI.Icon

  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :value, :any, default: nil
  attr :placeholder, :string, default: "Select date and time"
  attr :disabled, :boolean, default: false
  attr :label, :string, default: nil
  attr :suppress_events, :boolean, default: true

  def date_time_picker(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= if @label do %>
        <.label for={"#{@id}-input"}>{@label}</.label>
      <% end %>
      <div
        id={@id}
        phx-hook="DateTimePicker"
        class="date-picker-root w-full"
        data-value={format_datetime(@value)}
        data-name={@name}
        data-placeholder={@placeholder}
        data-disabled={@disabled}
        data-period={selected_period(@value)}
        data-suppress-events={@suppress_events}
      >
        <div class="relative">
          <.input
            id={"#{@id}-input"}
            type="text"
            class="pr-10"
            readonly
            disabled={@disabled}
            placeholder={@placeholder}
            value={format_datetime_display(@value)}
          />
          <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
            <.icon name="hero-calendar-days-solid" class="h-4 w-4 text-muted-foreground" />
          </div>
        </div>

        <div
          id={"#{@id}-calendar"}
          class="date-picker-dropdown absolute z-50 mt-1 hidden rounded-md border border-border bg-popover p-4 shadow-md animate-in fade-in-80 w-[280px]"
        >
          <div class="flex items-center justify-between mb-2">
            <.button variant="outline" size="icon" class="prev-month-btn" aria-label="Previous month">
              <.icon name="hero-chevron-left" class="h-4 w-4" />
            </.button>
            <span class="text-sm font-medium current-month-display"></span>
            <.button variant="outline" size="icon" class="next-month-btn" aria-label="Next month">
              <.icon name="hero-chevron-right" class="h-4 w-4" />
            </.button>
          </div>

          <div class="date-picker-calendar">
            <div class="grid grid-cols-7 gap-1 text-center text-xs text-muted-foreground mb-1.5">
              <div>Mo</div>
              <div>Tu</div>
              <div>We</div>
              <div>Th</div>
              <div>Fr</div>
              <div>Sa</div>
              <div>Su</div>
            </div>

            <div class="calendar-days">
              <!-- Days will be dynamically inserted by the JS hook -->
            </div>
          </div>

          <div class="flex items-center space-x-2 pt-4 border-t border-border mt-4">
            <.input
              id={"#{@id}-hour-input"}
              type="number"
              class="hour-input w-16 text-center"
              min="1"
              max="12"
              value={selected_hour(@value)}
              placeholder="HH"
            />
            <span class="text-muted-foreground">:</span>
            <.input
              id={"#{@id}-minute-input"}
              type="number"
              class="minute-input w-16 text-center"
              min="0"
              max="59"
              step="1"
              value={selected_minute_padded(@value)}
              placeholder="MM"
            />
            <div class="relative w-20">
              <.select
                :let={builder}
                id={"#{@id}-period-select"}
                name={"#{@id}-period"}
                value={selected_period(@value)}
                class="period-select w-full"
              >
                <.select_trigger builder={builder} class="h-9" />
                <.select_content builder={builder} class="w-full min-w-[5rem]">
                  <.select_group>
                    <.select_item builder={builder} value="AM" label="AM" />
                    <.select_item builder={builder} value="PM" label="PM" />
                  </.select_group>
                </.select_content>
              </.select>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Helper Functions ---

  # Format datetime to string (YYYY-MM-DD HH:MM:SS)
  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = datetime) do
    "#{datetime.year}-#{pad_number(datetime.month)}-#{pad_number(datetime.day)} " <>
      "#{pad_number(datetime.hour)}:#{pad_number(datetime.minute)}:#{pad_number(datetime.second)}"
  end

  defp format_datetime(_), do: ""

  # Get 12-hour format of hour
  defp get_12_hour_format(hour) do
    cond do
      # 00:00 -> 12 AM
      hour == 0 -> 12
      # 13-23 -> 1-11 PM
      hour > 12 -> hour - 12
      # 1-12 -> 1-12 AM/PM
      true -> hour
    end
  end

  # Pad a number to two digits (e.g., 1 -> "01", 10 -> "10")
  defp pad_number(number) do
    String.pad_leading("#{number}", 2, "0")
  end

  # Format datetime for display (MMM DD, YYYY at HH:MM AM/PM)
  defp format_datetime_display(nil), do: ""

  defp format_datetime_display(%DateTime{} = datetime) do
    # Format to match "March 11, 2025 at 12:02 PM" as shown in the image
    month = datetime |> DateTime.to_date() |> Calendar.strftime("%B")
    day = datetime.day
    year = datetime.year

    # Convert to 12-hour format
    {hour, period} =
      case datetime.hour do
        0 -> {12, "AM"}
        hour when hour < 12 -> {hour, "AM"}
        12 -> {12, "PM"}
        hour -> {hour - 12, "PM"}
      end

    minute = String.pad_leading("#{datetime.minute}", 2, "0")

    "#{month} #{day}, #{year} at #{hour}:#{minute} #{period}"
  end

  defp format_datetime_display(_), do: ""

  # Helper to get selected hour for Select component
  defp selected_hour(nil), do: nil

  defp selected_hour(%DateTime{} = datetime) do
    get_12_hour_format(datetime.hour)
  end

  defp selected_hour(_), do: nil

  # Helper to get selected minute padded
  defp selected_minute_padded(nil), do: nil

  defp selected_minute_padded(%DateTime{} = datetime) do
    pad_number(datetime.minute)
  end

  defp selected_minute_padded(_), do: nil

  # Helper to get selected period for Select component
  defp selected_period(nil), do: nil

  defp selected_period(%DateTime{} = datetime) do
    if datetime.hour >= 12, do: "PM", else: "AM"
  end

  defp selected_period(_), do: nil
end
