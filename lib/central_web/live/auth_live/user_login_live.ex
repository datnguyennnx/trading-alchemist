defmodule CentralWeb.AuthLive.UserLoginLive do
  use CentralWeb, :live_view
  import CentralWeb.CoreComponents
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.UI.Form
  import CentralWeb.Components.UI.Button

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center h-screen mx-auto max-w-sm">
      <.header class="text-center">
        Log in to account
        <:subtitle>
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Sign up
          </.link>
          for an account now.
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="login_form"
        action={~p"/users/log_in"}
        phx-update="ignore"
        class="space-y-6"
      >
        <.form_item>
          <.form_label>Email</.form_label>
          <.form_control>
            <.input field={@form[:email]} type="email" required />
          </.form_control>
          <.form_message field={@form[:email]} />
        </.form_item>

        <.form_item>
          <.form_label>Password</.form_label>
          <.form_control>
            <.input field={@form[:password]} type="password" required />
          </.form_control>
          <.form_message field={@form[:password]} />
        </.form_item>

        <div>
          <.error :if={@flash_error}>
            <%= @flash_error %>
          </.error>
        </div>

        <.form_item>
          <div class="flex items-center justify-between">
            <label class="flex items-center gap-2">
              <.input field={@form[:remember_me]} type="checkbox" />
              <span>Keep me logged in</span>
            </label>
            <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
              Forgot your password?
            </.link>
          </div>
        </.form_item>

        <div class="mt-6">
          <.button phx-disable-with="Logging in..." class="w-full">
            Log in
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    flash_error = Phoenix.Flash.get(socket.assigns.flash, :error)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form, flash_error: flash_error), temporary_assigns: [form: form]}
  end
end
