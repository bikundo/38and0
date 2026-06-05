defmodule Invincibles.Game.SimEngineTest do
  use ExUnit.Case, async: true
  alias Invincibles.Game.SimEngine

  setup do
    gk = %{stats: %{"div" => 90, "han" => 90, "kic" => 80, "ref" => 90, "spd" => 60, "pos" => 90}}
    df = %{stats: %{"pac" => 80, "sho" => 50, "pas" => 80, "dri" => 80, "def" => 90, "phy" => 90}}
    mf = %{stats: %{"pac" => 80, "sho" => 80, "pas" => 90, "dri" => 90, "def" => 80, "phy" => 80}}
    fw = %{stats: %{"pac" => 90, "sho" => 95, "pas" => 80, "dri" => 90, "def" => 40, "phy" => 80}}

    lineup = %{
      gk: gk,
      lb: df,
      cb1: df,
      cb2: df,
      rb: df,
      lm: mf,
      cm: mf,
      rm: mf,
      lw: fw,
      st: fw,
      rw: fw
    }

    %{lineup: lineup}
  end

  test "calculate_strengths/1 calculates correct values", %{lineup: lineup} do
    strengths = SimEngine.calculate_strengths(lineup)

    # Attack Strength = Sum of forwards' SHO (95 * 3 = 285) + (midfielders' PAS * 0.5 = 90 * 3 * 0.5 = 135) = 420
    assert strengths.attack == 420.0

    # Control Strength = Sum of midfielders' DRI/PAS (90*3 + 90*3 = 540) + (defenders' PAS * 0.3 = 80 * 4 * 0.3 = 96) = 636
    assert strengths.control == 636.0

    # Defensive Strength = Sum of defenders' DEF/PHY (90*4 + 90*4 = 720) + (midfielders' DEF * 0.5 = 80 * 3 * 0.5 = 120) = 840
    assert strengths.defense == 840.0

    # Goalkeeping Strength = Average of GK stats = (90+90+80+90+60+90)/6 = 500/6 = 83.333
    assert_in_delta strengths.gk, 83.333, 0.001
  end

  test "simulate_match/1 returns standard match result", %{lineup: lineup} do
    strengths = SimEngine.calculate_strengths(lineup)
    {result, gf, ga} = SimEngine.simulate_match(strengths)

    assert result in [:win, :draw, :loss]
    assert is_integer(gf)
    assert is_integer(ga)
  end

  test "simulate_season/1 runs simulation and halts on first non-win or goes to 38 games", %{lineup: lineup} do
    strengths = SimEngine.calculate_strengths(lineup)
    record = SimEngine.simulate_season(strengths)

    assert record.week >= 1 and record.week <= 38
    assert record.wins + record.draws + record.losses == record.week

    # If the run ended early, the last match must be a draw or loss
    if record.week < 38 do
      last_match = List.last(record.matches)
      assert last_match.result in [:draw, :loss]
    else
      # If completed 38 matches, check if we actually won all of them
      assert record.wins == 38
    end
  end
end
