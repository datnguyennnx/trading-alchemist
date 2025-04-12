defmodule CentralWeb.AuthLive.UserConfirmationLive do
  use CentralWeb, :live_view

  alias Central.Accounts
  import CentralWeb.CoreComponents
  import CentralWeb.Components.UI.Input
  import CentralWeb.Components.UI.Button

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="flex flex-col justify-center h-screen mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.form for={@form} id="confirmation_form" phx-submit="confirm_account" class="space-y-6">
        <.input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <div>
          <.error :if={@flash_error}>
            {@flash_error}
          </.error>
        </div>
        <div class="mt-6">
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
        </div>
      </.form>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    flash_error = Phoenix.Flash.get(socket.assigns.flash, :error)
    form = to_form(%{"token" => token}, as: "user")
    {:ok, assign(socket, form: form, flash_error: flash_error), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "User confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
