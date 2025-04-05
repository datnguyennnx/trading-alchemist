defmodule CentralWeb.AuthLive.UserRegistrationLive do
  use CentralWeb, :live_view

  alias Central.Accounts
  alias Central.Accounts.User
  import CentralWeb.CoreComponents
  import CentralWeb.Components.Input
  import CentralWeb.Components.Form
  import CentralWeb.Components.Button


  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center h-screen mx-auto max-w-sm">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in?_action=registered"}
        method="post"
        class="space-y-6"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

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

        <div class="mt-6">
          <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
        </div>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
