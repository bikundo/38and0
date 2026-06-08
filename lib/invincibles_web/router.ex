defmodule InvinciblesWeb.Router do
  use InvinciblesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {InvinciblesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", InvinciblesWeb do
    pipe_through :browser

    live "/", GameLive
    live "/share/:id", ShareLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", InvinciblesWeb do
  #   pipe_through :api
  # end
end
