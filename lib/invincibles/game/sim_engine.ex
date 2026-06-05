defmodule Invincibles.Game.SimEngine do
  @moduledoc """
  Core computational match engine that simulates Premier League matches.
  """

  @opponent_baseline %{
    attack: 360.0,
    control: 576.0,
    defense: 760.0,
    gk: 80.0
  }

  @doc """
  Calculates the aggregate strengths for a user lineup.
  """
  def calculate_strengths(lineup) do
    # Extract players by position group
    gks = [lineup.gk] |> Enum.reject(&is_nil/1)
    dfs = [lineup.lb, lineup.cb1, lineup.cb2, lineup.rb] |> Enum.reject(&is_nil/1)
    mfs = [lineup.lm, lineup.cm, lineup.rm] |> Enum.reject(&is_nil/1)
    fws = [lineup.lw, lineup.st, lineup.rw] |> Enum.reject(&is_nil/1)

    # Attack Strength = Sum of forwards' SHO + (midfielders' PAS * 0.5)
    fw_sho = sum_stat(fws, "sho")
    mf_pas = sum_stat(mfs, "pas")
    attack_strength = fw_sho + (mf_pas * 0.5)

    # Control Strength = Sum of midfielders' DRI/PAS + (defenders' PAS * 0.3)
    mf_dri_pas = sum_stat(mfs, "dri") + sum_stat(mfs, "pas")
    df_pas = sum_stat(dfs, "pas")
    control_strength = mf_dri_pas + (df_pas * 0.3)

    # Defensive Strength = Sum of defenders' DEF/PHY + (midfielders' DEF * 0.5)
    df_def_phy = sum_stat(dfs, "def") + sum_stat(dfs, "phy")
    mf_def = sum_stat(mfs, "def")
    defensive_strength = df_def_phy + (mf_def * 0.5)

    # Goalkeeping Strength = GK's baseline attributes
    gk_strength =
      case gks do
        [gk] ->
          # Average of div, han, kic, ref, spd, pos
          stats = gk.stats || %{}
          div = Map.get(stats, "div", 50)
          han = Map.get(stats, "han", 50)
          kic = Map.get(stats, "kic", 50)
          ref = Map.get(stats, "ref", 50)
          spd = Map.get(stats, "spd", 50)
          pos = Map.get(stats, "pos", 50)
          (div + han + kic + ref + spd + pos) / 6.0

        [] ->
          50.0
      end

    %{
      attack: attack_strength,
      control: control_strength,
      defense: defensive_strength,
      gk: gk_strength
    }
  end

  # Helper to sum a specific stat key from a list of appearances
  defp sum_stat(appearances, stat_key) do
    Enum.reduce(appearances, 0, fn app, acc ->
      stats = app.stats || %{}
      # Map keys might be atoms or strings depending on how they are loaded/decoded
      val = Map.get(stats, stat_key) || Map.get(stats, String.to_atom(stat_key)) || 50
      acc + val
    end)
  end

  @doc """
  Simulates a single match between the User and the Opponent.
  Returns `{:win | :draw | :loss, user_goals, opp_goals}`.
  """
  def simulate_match(user_strengths) do
    # Simulates 5 possessions per match
    {user_goals, opp_goals} =
      Enum.reduce(1..5, {0, 0}, fn _possession_index, {u_goals, o_goals} ->
        # 1. Control check with random variance
        user_variance = 0.7 + :rand.uniform() * 0.6
        opp_variance = 0.7 + :rand.uniform() * 0.6

        user_control = user_strengths.control * user_variance
        opp_control = @opponent_baseline.control * opp_variance

        if user_control >= opp_control do
          # User attacks
          if score_check?(user_strengths.attack, @opponent_baseline.defense, @opponent_baseline.gk) do
            {u_goals + 1, o_goals}
          else
            {u_goals, o_goals}
          end
        else
          # Opponent attacks
          if score_check?(@opponent_baseline.attack, user_strengths.defense, user_strengths.gk) do
            {u_goals, o_goals + 1}
          else
            {u_goals, o_goals}
          end
        end
      end)

    result =
      cond do
        user_goals > opp_goals -> :win
        user_goals == opp_goals -> :draw
        true -> :loss
      end

    {result, user_goals, opp_goals}
  end

  # Check if an attack results in a goal
  defp score_check?(attack_strength, defense_strength, gk_strength) do
    # 2. Shot quality check
    ratio = attack_strength / max(defense_strength, 1.0)

    # 3. Goalkeeper check with Gaussian variance (:rand.normal/0)
    # Average ratio is ~0.5. Ratio * 150 = ~75.
    # GK average OVR is 80.
    # Score value = Ratio * 150 + normal() * 20 - GK
    # If positive, it's a goal.
    shot_value = ratio * 150.0 + :rand.normal() * 20.0
    shot_value > gk_strength
  end

  @doc """
  Simulates a 38-game season.
  If any match is not a win, it breaks out early and returns the season history up to that point.
  """
  def simulate_season(user_strengths) do
    Enum.reduce_while(1..38, %{week: 0, wins: 0, draws: 0, losses: 0, gf: 0, ga: 0, matches: []}, fn week, acc ->
      {result, gf, ga} = simulate_match(user_strengths)

      match_detail = %{
        week: week,
        result: result,
        gf: gf,
        ga: ga
      }

      new_acc = %{
        week: week,
        wins: acc.wins + (if result == :win, do: 1, else: 0),
        draws: acc.draws + (if result == :draw, do: 1, else: 0),
        losses: acc.losses + (if result == :loss, do: 1, else: 0),
        gf: acc.gf + gf,
        ga: acc.ga + ga,
        matches: acc.matches ++ [match_detail]
      }

      if result == :win do
        {:cont, new_acc}
      else
        {:halt, new_acc}
      end
    end)
  end
end
