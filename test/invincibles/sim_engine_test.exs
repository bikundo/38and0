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

    assert strengths.attack == 93.5
    assert strengths.control == 87.0
    assert strengths.defense == 87.0
    assert_in_delta strengths.gk, 83.333, 0.001
  end

  test "simulate_match/1 returns standard match result", %{lineup: lineup} do
    strengths = SimEngine.calculate_strengths(lineup)
    {result, gf, ga} = SimEngine.simulate_match(strengths)

    assert result in [:win, :draw, :loss]
    assert is_integer(gf)
    assert is_integer(ga)
  end

  test "simulate_match/2 accepts custom opponent strengths", %{lineup: lineup} do
    strengths = SimEngine.calculate_strengths(lineup)
    opp_strengths = %{attack: 90.0, control: 90.0, defense: 90.0, gk: 90.0}

    {result, gf, ga} = SimEngine.simulate_match(strengths, opp_strengths)

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

    first_match = hd(record.matches)
    assert Map.has_key?(first_match, :week)
    assert Map.has_key?(first_match, :result)
    assert Map.has_key?(first_match, :gf)
    assert Map.has_key?(first_match, :ga)
    assert Map.has_key?(first_match, :opponent)
    assert Map.has_key?(first_match, :opponent_short)
  end
end
