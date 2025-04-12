defmodule CentralWeb.Component do
  @moduledoc """
  The entrypoint for defining UI components.

  This can be used in your components as:

    use CentralWeb.Component

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  defmacro __using__(_) do
    quote do
      use Phoenix.Component

      import CentralWeb.ComponentHelpers
      import TwMerge

      alias Phoenix.LiveView.JS

      defp classes(input) do
        TwMerge.merge(input)
      end
    end
  end
end
