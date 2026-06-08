defmodule InvinciblesWeb.SitemapController do
  use InvinciblesWeb, :controller
  alias Invincibles.Repo
  alias Invincibles.Game.Appearance
  import Ecto.Query

  def index(conn, _params) do
    # Fetch unique club names and seasons from database appearances
    query =
      from(a in Appearance,
        join: c in assoc(a, :club),
        group_by: [c.name, a.season],
        select: {c.name, a.season}
      )

    squads = Repo.all(query)
    xml = InvinciblesWeb.SitemapXML.render("index.xml", %{squads: squads})

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, xml)
  end
end
