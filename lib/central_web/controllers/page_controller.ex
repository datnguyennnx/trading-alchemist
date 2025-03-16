defmodule CentralWeb.PageController do
  use CentralWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
