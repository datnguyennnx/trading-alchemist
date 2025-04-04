defmodule CentralWeb.UserResetPasswordLive do
  use CentralWeb, :live_view
  import CentralWeb.CoreComponents
  import CentralWeb.Components.Input
  import CentralWeb.Components.Form
  import CentralWeb.Components.Button

  alias Central.Accounts

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center h-screen mx-auto max-w-sm">
      <.header class="text-center">Reset Password</.header>

      <.form
        for={@form}
        id="reset_password_form"
        phx-submit="reset_password"
        phx-change="validate"
        class="space-y-6"
      >
        <.error :if={@form.errors != []}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.form_item>
          <.form_label>New password</.form_label>
          <.form_control>
            <.input field={@form[:password]} type="password" required />
          </.form_control>
          <.form_message field={@form[:password]} />
        </.form_item>

        <.form_item>
          <.form_label>Confirm new password</.form_label>
          <.form_control>
            <.input field={@form[:password_confirmation]} type="password" required />
          </.form_control>
          <.form_message field={@form[:password_confirmation]} />
        </.form_item>

        <div class="mt-6">
          <.button phx-disable-with="Resetting..." class="w-full">Reset Password</.button>
        </div>
      </.form>

      <p class="text-center text-sm mt-4">
        <.link href={~p"/users/register"}>Register</.link>
        | <.link href={~p"/users/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_user_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{user: user} ->
          Accounts.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/users/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
