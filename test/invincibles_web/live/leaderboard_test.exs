defmodule InvinciblesWeb.LeaderboardTest do
  use InvinciblesWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Invincibles.Repo
  alias Invincibles.Game

  setup do
    club =
      Repo.insert!(%Invincibles.Game.Club{
        name: "Leaderboard FC",
        short_name: "LFC",
        primary_color: "#111"
      })

    player =
      Repo.insert!(%Invincibles.Game.Player{
        name: "Test Leader",
        display_name: "T. Leader",
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

  test "Leaderboard displays empty state when no shares exist", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")
    assert html =~ "No campaigns active"
    assert html =~ "Manager Leaderboard"
  end

  test "Leaderboard lists shares in correct sorted order", %{conn: conn, appearance: app} do
    lineup = %{gk: app}

    # Share 1: 98 points
    record1 = %{wins: 30, draws: 8, losses: 0, gf: 80, ga: 20, week: 38}
    {:ok, share1} = Game.create_share(lineup, "4-3-3", record1, "Season A", "Quote A")

    # Share 2: 114 points (Perfect)
    record2 = %{wins: 38, draws: 0, losses: 0, gf: 100, ga: 10, week: 38}
    {:ok, share2} = Game.create_share(lineup, "4-3-3", record2, "Season B", "Quote B")

    # Share 3: 97 points
    record3 = %{wins: 30, draws: 7, losses: 1, gf: 80, ga: 20, week: 38}
    {:ok, share3} = Game.create_share(lineup, "4-3-3", record3, "Season C", "Quote C")

    {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")

    # Verify the manager leaderboard title is present
    assert html =~ "Manager Leaderboard"

    # Verify all seasons are listed
    assert html =~ "Season A"
    assert html =~ "Season B"
    assert html =~ "Season C"

    # Verify quote display
    assert html =~ "Quote A"
    assert html =~ "Quote B"
    assert html =~ "Quote C"

    # Verify they contain their respective links
    assert html =~ "/share/#{share1.id}"
    assert html =~ "/share/#{share2.id}"
    assert html =~ "/share/#{share3.id}"

    # Let's ensure they appear in sorted order: Season B (114 pts), Season A (98 pts), Season C (97 pts)
    # We can check this by testing substrings indexes in HTML
    idx_b = string_indev(html, "Season B")
    idx_a = string_indev(html, "Season A")
    idx_c = string_indev(html, "Season C")

    assert idx_b < idx_a
    assert idx_a < idx_c
  end

  # Helper helper to find index of a substring
  defp string_indev(string, substring) do
    case :binary.match(string, substring) do
      {pos, _len} -> pos
      :nomatch -> nil
    end
  end
end
