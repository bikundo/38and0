defmodule InvinciblesWeb.SitemapControllerTest do
  use InvinciblesWeb.ConnCase
  alias Invincibles.Repo

  setup do
    club =
      Repo.insert!(%Invincibles.Game.Club{
        name: "Sitemap United",
        short_name: "SMUT",
        primary_color: "#000"
      })

    player =
      Repo.insert!(%Invincibles.Game.Player{
        name: "Sitemap Star",
        display_name: "S. Star",
        primary_position: "MF"
      })

    _appearance =
      Repo.insert!(%Invincibles.Game.Appearance{
        player: player,
        club: club,
        season: "1998-99",
        era: "90s",
        ovr: 85,
        stats: %{
          "pac" => 80,
          "sho" => 80,
          "pas" => 80,
          "dri" => 80,
          "def" => 80,
          "phy" => 80
        }
      })

    {:ok, club: club}
  end

  test "GET /sitemap.xml", %{conn: conn, club: _club} do
    conn = get(conn, ~p"/sitemap.xml")
    response = response(conn, 200)

    assert response =~ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    assert response =~ "<urlset"
    assert response =~ "https://invincibles.website/squads"
    assert response =~ "https://invincibles.website/squads/sitemap-united"
    assert response =~ "https://invincibles.website/squads/sitemap-united/1998-99"
    assert response =~ "</urlset>"
    assert response_content_type(conn, :xml) =~ "text/xml"
  end
end
