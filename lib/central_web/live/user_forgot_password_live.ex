defmodule CentralWeb.UserForgotPasswordLive do
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
        Forgot your password?
        <:subtitle>We'll send a password reset link to your inbox</:subtitle>
      </.header>

      <.form for={@form} id="reset_password_form" phx-submit="send_email" class="space-y-6">
        <.form_item>
          <.form_label>Email</.form_label>
          <.form_control>
            <.input field={@form[:email]} type="email" placeholder="Email" required />
          </.form_control>
          <.form_message field={@form[:email]} />
        </.form_item>

        <div class="mt-6">
          <.button phx-disable-with="Sending..." class="w-full">
            Send password reset instructions
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
