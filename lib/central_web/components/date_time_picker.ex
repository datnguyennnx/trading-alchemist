defmodule CentralWeb.Components.DateTimePicker do
  use Phoenix.Component

  @doc """
  Renders a date picker as a HTML5 date input.

  ## Assigns
    - `id` (string) - The HTML `id` attribute for the input.
    - `name` (string) - The HTML `name` attribute for the input.
    - `value` (Date or NaiveDateTime) - The current value to display in the picker.
      When a `NaiveDateTime` is given, only the date part is used.
    - `label` (string, optional) - An optional label to render above the input.
    - `class` (string, optional) - Any additional CSS classes.
    - `display_format` (string, optional) - A custom date format for display. The default is `"%Y-%m-%d"`, which matches the HTML5 `date` input requirements.

  ## Examples

      <.date_picker
        id="appointment_date"
        name="appointment_date"
        label="Choose Date"
        value={@appointment_date}
        display_format="%Y-%m-%d"
      />
  """
  def date_picker(assigns) do
    assigns =
      assigns
      |> Phoenix.Component.assign_new(:label, fn -> nil end)
      |> Phoenix.Component.assign_new(:value, fn -> nil end)
      |> Phoenix.Component.assign_new(:class, fn -> "" end)
      |> Phoenix.Component.assign_new(:display_format, fn -> "%Y-%m-%d" end)

    ~H"""
    <div class="date-picker">
      <%= if @label do %>
        <label for={@id}>{@label}</label>
      <% end %>
      <input
        type="date"
        id={@id}
        name={@name}
        class={@class}
        value={format_date(@value, @display_format)}
        phx-hook="DatePickerHook"
      />
      <!--
        The phx-hook is optional and can be used if you wish to attach
        some JavaScript behavior to enhance the native date-picker.
      -->
    </div>
    """
  end

  @doc """
  Renders a datetime picker as a HTML5 datetime-local input.

  ## Assigns
    - `id` (string) - The HTML `id` attribute for the input.
    - `name` (string) - The HTML `name` attribute for the input.
    - `value` (DateTime or NaiveDateTime) - The current value to display in the picker.
    - `class` (string, optional) - Any additional CSS classes.
    - `required` (boolean, optional) - Whether the field is required.

  ## Examples

      <.datetime_picker
        id="appointment_datetime"
        name="appointment_datetime"
        value={@appointment_datetime}
        class="input-control"
        required={true}
      />
  """
  def datetime_picker(assigns) do
    assigns =
      assigns
      |> Phoenix.Component.assign_new(:value, fn -> nil end)
      |> Phoenix.Component.assign_new(:class, fn -> "" end)
      |> Phoenix.Component.assign_new(:required, fn -> false end)

    ~H"""
    <div class="datetime-picker">
      <input
        type="datetime-local"
        id={@id}
        name={@name}
        class={@class}
        value={format_datetime(@value)}
        required={@required}
        phx-hook="DateTimePickerHook"
      />
    </div>
    """
  end

  # Helper function: returns an empty string if there's no value,
  # otherwise it formats a Date or NaiveDateTime according to the display_format.
  defp format_date(nil, _format), do: ""

  defp format_date(%Date{} = date, format) do
    Calendar.strftime(date, format)
  end

  defp format_date(%NaiveDateTime{} = ndt, format) do
    ndt
    |> NaiveDateTime.to_date()
    |> format_date(format)
  end

  # Format date time to HTML5 datetime-local input format
  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    dt
    |> DateTime.to_naive()
    |> format_datetime()
  end

  defp format_datetime(%NaiveDateTime{} = ndt) do
    # Format as "YYYY-MM-DDTHH:MM" for datetime-local input
    NaiveDateTime.to_iso8601(ndt)
    # Remove seconds and timezone
    |> String.replace(~r/\:\d{2}\.\d+Z?$/, "")
  end
end
