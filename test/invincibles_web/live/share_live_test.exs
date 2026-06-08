defmodule InvinciblesWeb.ShareLiveTest do
  use InvinciblesWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Invincibles.Repo
  alias Invincibles.Game

  # Setup database record
  setup do
    club =
      Repo.insert!(%Invincibles.Game.Club{
        name: "Integration Share FC",
        short_name: "ISFC",
        primary_color: "#111"
      })

    player =
      Repo.insert!(%Invincibles.Game.Player{
        name: "Test Int",
        display_name: "T. Int",
        primary_position: "GK"
      })

    appearance =
      Repo.insert!(%Invincibles.Game.Appearance{
        player: player,
        club: club,
        season: "2023-24",
        era: "Modern",
        ovr: 88,
        stats: %{}
      })

    {:ok, appearance: appearance}
  end

  test "ShareLive renders shared lineup card successfully", %{conn: conn, appearance: app} do
    lineup = %{gk: app}
    record = %{wins: 38, draws: 0, losses: 0, gf: 110, ga: 10, week: 38}
    funny_quote = "Perfect Run"

    {:ok, share} = Game.create_share(lineup, "4-3-3", record, "2023-24", funny_quote)

    {:ok, _view, html} = live(conn, ~p"/share/#{share.id}")
    assert html =~ "Int"
    assert html =~ "Perfect Run"
    assert html =~ "38W - 0D - 0L"
  end

  test "ShareLive redirects to homepage on invalid or missing share ID", %{conn: conn} do
    random_uuid = Ecto.UUID.generate()

    # Assert redirect occurs to "/"
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/share/#{random_uuid}")
  end
end
