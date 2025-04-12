defmodule CentralWeb.AuthLive.UserSettingsLive do
  use CentralWeb, :live_view
  import CentralWeb.CoreComponents
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.UI.Form
  import CentralWeb.Components.UI.Button

  alias Central.Accounts

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center h-screen mx-auto max-w-sm">
      <.header class="text-center">
        Password Settings
        <:subtitle>Update your account password</:subtitle>
      </.header>
      <div>
        <.form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
          class="space-y-6"
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />

          <.form_item>
            <.form_label>New password</.form_label>
            <.form_control>
              <.input field={@password_form[:password]} type="password" required />
            </.form_control>
            <.form_message field={@password_form[:password]} />
          </.form_item>

          <.form_item>
            <.form_label>Confirm new password</.form_label>
            <.form_control>
              <.input field={@password_form[:password_confirmation]} type="password" />
            </.form_control>
            <.form_message field={@password_form[:password_confirmation]} />
          </.form_item>

          <.form_item>
            <.form_label>Current password</.form_label>
            <.form_control>
              <.input
                field={@password_form[:current_password]}
                name="current_password"
                type="password"
                id="current_password_for_password"
                value={@current_password}
                required
              />
            </.form_control>
            <.form_message field={@password_form[:current_password]} />
          </.form_item>

          <div>
            <.error :if={@flash_error}>
              <%= @flash_error %>
            </.error>
          </div>

          <div class="mt-6">
            <.button phx-disable-with="Changing...">Change Password</.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def mount(%{"token" => _token}, _session, socket) do
    socket = put_flash(socket, :error, "Invalid request.")
    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    password_changeset = Accounts.change_user_password(user)
    flash_error = Phoenix.Flash.get(socket.assigns.flash, :error)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:flash_error, flash_error)

    {:ok, socket}
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(password_form: to_form(changeset))
         |> assign(flash_error: "Failed to update password. Please check the form for errors.")
        }
    end
  end
end
