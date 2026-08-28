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

  test "Leaderboard displays empty state when no shares exist and displays 0 total games played",
       %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")
    assert html =~ "No campaigns active"
    assert html =~ "Manager Leaderboard"
    assert html =~ "0 total games played"
  end

  test "Leaderboard lists shares in correct sorted order", %{conn: conn, appearance: app} do
    lineup = %{gk: app}

    record1 = %{wins: 30, draws: 8, losses: 0, gf: 80, ga: 20, week: 38}
    {:ok, share1} = Game.create_share(lineup, "4-3-3", record1, "Season A", "Quote A")

    record2 = %{wins: 38, draws: 0, losses: 0, gf: 100, ga: 10, week: 38}
    {:ok, share2} = Game.create_share(lineup, "4-3-3", record2, "Season B", "Quote B")

    record3 = %{wins: 30, draws: 7, losses: 1, gf: 80, ga: 20, week: 38}
    {:ok, share3} = Game.create_share(lineup, "4-3-3", record3, "Season C", "Quote C")

    {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")

    assert html =~ "Manager Leaderboard"
    assert html =~ "3 total games played"

    assert html =~ "Season A"
    assert html =~ "Season B"
    assert html =~ "Season C"

    assert html =~ "Quote A"
    assert html =~ "Quote B"
    assert html =~ "Quote C"

    assert html =~ "/share/#{share1.id}"
    assert html =~ "/share/#{share2.id}"
    assert html =~ "/share/#{share3.id}"

    idx_b = string_indev(html, "Season B")
    idx_a = string_indev(html, "Season A")
    idx_c = string_indev(html, "Season C")

    assert idx_b < idx_a
    assert idx_a < idx_c
  end

  test "Leaderboard displays at most 20 entries", %{conn: conn, appearance: app} do
    lineup = %{gk: app}

    for i <- 1..25 do
      label = :io_lib.format("Season ~2..0B", [i]) |> List.to_string()
      record = %{wins: i, draws: 0, losses: 38 - i, gf: i, ga: 0, week: 38}
      {:ok, _share} = Game.create_share(lineup, "4-3-3", record, label, "Quote #{i}")
    end

    {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")

    for i <- 6..25 do
      label = :io_lib.format("Season ~2..0B", [i]) |> List.to_string()
      assert html =~ label
    end

    for i <- 1..5 do
      label = :io_lib.format("Season ~2..0B", [i]) |> List.to_string()
      refute html =~ label
    end
  end

  test "simulation completion automatically saves the campaign", %{conn: conn, appearance: app} do
    club = Repo.get!(Invincibles.Game.Club, app.club_id)

    insert_mock_squad(club)

    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("button", "AUTO DRAFT SQUAD") |> render_click()

    view |> render_click("simulate_season")

    for _i <- 1..39 do
      send(view.pid, :tick_simulation)
    end

    _html = render(view)

    shares = Game.list_active_shares()
    assert length(shares) == 1
    share = hd(shares)
    assert share.season_label != ""
    assert share.funny_quote != ""
  end

  defp insert_mock_squad(club) do
    positions = [
      {"LB", "DF", "lb"},
      {"CB1", "DF", "cb1"},
      {"CB2", "DF", "cb2"},
      {"RB", "DF", "rb"},
      {"LM", "MF", "lm"},
      {"CM", "MF", "cm"},
      {"RM", "MF", "rm"},
      {"LW", "FW", "lw"},
      {"ST", "FW", "st"},
      {"RW", "FW", "rw"}
    ]

    for {name, pos, _slot} <- positions do
      player =
        Repo.insert!(%Invincibles.Game.Player{
          name: name,
          display_name: name,
          primary_position: pos
        })

      Repo.insert!(%Invincibles.Game.Appearance{
        player: player,
        club: club,
        season: "2023-24",
        era: "Modern",
        ovr: 85,
        stats: %{
          "pac" => 85,
          "sho" => 85,
          "pas" => 85,
          "dri" => 85,
          "def" => 85,
          "phy" => 85,
          "div" => 85,
          "han" => 85,
          "kic" => 85,
          "ref" => 85,
          "spd" => 85,
          "pos" => 85
        }
      })
    end
  end

  defp string_indev(string, substring) do
    case :binary.match(string, substring) do
      {pos, _len} -> pos
      :nomatch -> nil
    end
  end
end
