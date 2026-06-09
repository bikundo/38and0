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

    # Attack Strength = Average forward SHO (95 * 0.7 = 66.5) + Average midfielder PAS (90 * 0.3 = 27.0) = 93.5
    assert strengths.attack == 93.5

    # Control Strength = Average midfielder (DRI+PAS)/2 (90 * 0.7 = 63.0) + Average defender PAS (80 * 0.3 = 24.0) = 87.0
    assert strengths.control == 87.0

    # Defensive Strength = Average defender (DEF+PHY)/2 (90 * 0.7 = 63.0) + Average midfielder DEF (80 * 0.3 = 24.0) = 87.0
    assert strengths.defense == 87.0

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

  test "simulate_season/1 always plays all 38 games", %{lineup: lineup} do
    strengths = SimEngine.calculate_strengths(lineup)
    record = SimEngine.simulate_season(strengths)

    assert record.week == 38
    assert length(record.matches) == 38
    assert record.wins + record.draws + record.losses == 38
    assert record.wins >= 0 and record.draws >= 0 and record.losses >= 0
  end
end
