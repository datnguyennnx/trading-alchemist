defmodule CentralWeb.UserConfirmationInstructionsLive do
  use CentralWeb, :live_view

  alias Central.Accounts
  import CentralWeb.CoreComponents
  import CentralWeb.Components.Input
  import CentralWeb.Components.Form
  import CentralWeb.Components.Button

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center h-screen mx-auto max-w-sm">
      <.header class="text-center">
        No confirmation instructions received?
        <:subtitle>We'll send a new confirmation link to your inbox</:subtitle>
      </.header>

      <.form for={@form} id="resend_confirmation_form" phx-submit="send_instructions" class="space-y-6">
        <.form_item>
          <.form_label>Email</.form_label>
          <.form_control>
            <.input field={@form[:email]} type="email" placeholder="Email" required />
          </.form_control>
          <.form_message field={@form[:email]} />
        </.form_item>

        <div class="mt-6 flex justify-end">
          <.button phx-disable-with="Sending..." class="w-full">
            Resend confirmation instructions
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
