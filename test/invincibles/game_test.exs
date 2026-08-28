defmodule Invincibles.GameTest do
  use Invincibles.DataCase
  alias Invincibles.Game
  alias Invincibles.Game.{Club, Player, Appearance}

  setup do
    club = Repo.insert!(%Club{name: "Draft FC", short_name: "DFC", primary_color: "#123"})

    players =
      for {name, pos} <- [
            {"GK Player", "GK"},
            {"LB Player", "DF"},
            {"CB1 Player", "DF"},
            {"CB2 Player", "DF"},
            {"CB3 Player", "DF"},
            {"RB Player", "DF"},
            {"LM Player", "MF"},
            {"CM Player", "MF"},
            {"RM Player", "MF"},
            {"LW Player", "FW"},
            {"ST Player", "FW"},
            {"RW Player", "FW"}
          ] do
        p = Repo.insert!(%Player{name: name, display_name: name, primary_position: pos})

        Repo.insert!(%Appearance{
          player: p,
          club: club,
          season: "2023-24",
          era: "20s",
          ovr: 85,
          stats: %{"pac" => 80, "sho" => 80, "pas" => 80, "dri" => 80, "def" => 80, "phy" => 80}
        })
      end

    {:ok, club: club, players: players}
  end

  test "auto_draft_lineup/2 fills all empty slots without error" do
    empty_lineup = %{
      gk: nil,
      lb: nil,
      cb1: nil,
      cb2: nil,
      cb3: nil,
      rb: nil,
      lm: nil,
      cm: nil,
      rm: nil,
      lw: nil,
      st: nil,
      rw: nil
    }

    active_slots = [:gk, :lb, :cb1, :cb2, :rb, :lm, :cm, :rm, :lw, :st, :rw]
    lineup = Game.auto_draft_lineup(empty_lineup, active_slots)

    for slot <- active_slots do
      assert %Appearance{} = Map.get(lineup, slot)
    end
  end
end
