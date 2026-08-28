defmodule InvinciblesWeb.DirectoryLiveTest do
  use InvinciblesWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Invincibles.Repo

  setup do
    club =
      Repo.insert!(%Invincibles.Game.Club{
        name: "Test United",
        short_name: "TUTD",
        primary_color: "#770000"
      })

    player =
      Repo.insert!(%Invincibles.Game.Player{
        name: "Test Star",
        display_name: "T. Star",
        primary_position: "FW"
      })

    appearance =
      Repo.insert!(%Invincibles.Game.Appearance{
        player: player,
        club: club,
        season: "2007-08",
        era: "00s",
        ovr: 92,
        stats: %{
          "pac" => 95,
          "sho" => 92,
          "pas" => 88,
          "dri" => 90,
          "def" => 45,
          "phy" => 80
        }
      })

    {:ok, club: club, player: player, appearance: appearance}
  end

  test "DirectoryLive index renders all clubs successfully", %{conn: conn, club: club} do
    {:ok, _view, html} = live(conn, ~p"/squads")
    assert html =~ "Premier League Retro Squads"
    assert html =~ club.name
    assert html =~ club.short_name
    assert html =~ "application/ld+json"
    assert html =~ "ItemList"
  end

  test "DirectoryLive club page renders seasons successfully", %{conn: conn, club: club} do
    {:ok, _view, html} = live(conn, ~p"/squads/test-united")
    assert html =~ club.name
    assert html =~ "2007-08"
    assert html =~ "application/ld+json"
  end

  test "DirectoryLive squad page renders squad sheet successfully", %{
    conn: conn,
    club: club,
    player: player
  } do
    {:ok, _view, html} = live(conn, ~p"/squads/test-united/2007-08")
    assert html =~ club.name
    assert html =~ "2007-08 Squad"
    assert html =~ player.display_name
    assert html =~ "92"
    assert html =~ "PAC"
    assert html =~ "95"
    assert html =~ "application/ld+json"
    assert html =~ "FAQPage"
  end

  test "GameLive initializes with preset club_id and season query parameters", %{
    conn: conn,
    club: club
  } do
    {:ok, _view, html} = live(conn, ~p"/?club_id=#{club.id}&season=2007-08")
    assert html =~ "Test Star"
    assert html =~ "Drafting"
  end
end
