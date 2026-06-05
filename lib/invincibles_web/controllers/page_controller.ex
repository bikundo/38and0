defmodule InvinciblesWeb.PageController do
  use InvinciblesWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
