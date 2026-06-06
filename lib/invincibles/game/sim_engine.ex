defmodule Invincibles.Game.SimEngine do
  @moduledoc """
  Core computational match engine that simulates Premier League matches.
  """
  import Ecto.Query
  alias Invincibles.Repo
  alias Invincibles.Game.Appearance
  alias Invincibles.Game.Club

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
    # Extract players by position group dynamically.
    # Support both database appearances (preloaded with :player) and mock test maps (key-based lookups).
    all_players = Map.values(lineup) |> Enum.reject(&is_nil/1)

    has_player_structs? = Enum.any?(all_players, &Map.has_key?(&1, :player))

    {gks, dfs, mfs, fws} =
      if has_player_structs? do
        gks = Enum.filter(all_players, &(&1.player.primary_position == "GK"))
        dfs = Enum.filter(all_players, &(&1.player.primary_position == "DF"))
        mfs = Enum.filter(all_players, &(&1.player.primary_position == "MF"))
        fws = Enum.filter(all_players, &(&1.player.primary_position == "FW"))
        {gks, dfs, mfs, fws}
      else
        gks = [Map.get(lineup, :gk)] |> Enum.reject(&is_nil/1)

        dfs =
          [
            Map.get(lineup, :lb),
            Map.get(lineup, :cb1),
            Map.get(lineup, :cb2),
            Map.get(lineup, :cb3),
            Map.get(lineup, :rb)
          ]
          |> Enum.reject(&is_nil/1)

        mfs =
          [
            Map.get(lineup, :lm),
            Map.get(lineup, :cm),
            Map.get(lineup, :cm1),
            Map.get(lineup, :cm2),
            Map.get(lineup, :cm3),
            Map.get(lineup, :rm)
          ]
          |> Enum.reject(&is_nil/1)

        fws =
          [
            Map.get(lineup, :lw),
            Map.get(lineup, :st),
            Map.get(lineup, :st1),
            Map.get(lineup, :st2),
            Map.get(lineup, :rw)
          ]
          |> Enum.reject(&is_nil/1)

        {gks, dfs, mfs, fws}
      end

    # Attack Strength = Sum of forwards' SHO + (midfielders' PAS * 0.5)
    fw_sho = sum_stat(fws, "sho")
    mf_pas = sum_stat(mfs, "pas")
    attack_strength = fw_sho + mf_pas * 0.5

    # Control Strength = Sum of midfielders' DRI/PAS + (defenders' PAS * 0.3)
    mf_dri_pas = sum_stat(mfs, "dri") + sum_stat(mfs, "pas")
    df_pas = sum_stat(dfs, "pas")
    control_strength = mf_dri_pas + df_pas * 0.3

    # Defensive Strength = Sum of defenders' DEF/PHY + (midfielders' DEF * 0.5)
    df_def_phy = sum_stat(dfs, "def") + sum_stat(dfs, "phy")
    mf_def = sum_stat(mfs, "def")
    defensive_strength = df_def_phy + mf_def * 0.5

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
          if score_check?(
               user_strengths.attack,
               @opponent_baseline.defense,
               @opponent_baseline.gk
             ) do
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
  Simulates a full 38-game season.
  Plays games against actual historical opponents from a randomly selected season if database is checked out (otherwise falls back to static baseline).
  """
  def simulate_season(user_strengths) do
    has_db? =
      try do
        Repo.query!("SELECT 1")
        true
      rescue
        _ -> false
      end

    if has_db? do
      simulate_opponents_season(user_strengths)
    else
      simulate_static_season(user_strengths)
    end
  end

  # Static simulation fallback (e.g. for unit tests that run asynchronously without sandbox checked out)
  defp simulate_static_season(user_strengths) do
    Enum.reduce(
      1..38,
      %{week: 0, wins: 0, draws: 0, losses: 0, gf: 0, ga: 0, matches: []},
      fn week, acc ->
        {result, gf, ga} = simulate_match(user_strengths)

        match_detail = %{
          week: week,
          result: result,
          gf: gf,
          ga: ga,
          opponent: "Static Opponent",
          opponent_short: "OPP"
        }

        %{
          week: week,
          wins: acc.wins + if(result == :win, do: 1, else: 0),
          draws: acc.draws + if(result == :draw, do: 1, else: 0),
          losses: acc.losses + if(result == :loss, do: 1, else: 0),
          gf: acc.gf + gf,
          ga: acc.ga + ga,
          matches: acc.matches ++ [match_detail]
        }
      end
    )
    |> Map.put(:season_label, "Simulation Mode")
  end

  # Realistic simulation playing against 19 dynamic opponents twice from a random season
  defp simulate_opponents_season(user_strengths) do
    season = select_random_season() || "2003-2004"
    clubs = get_clubs_for_season(season)

    if Enum.empty?(clubs) do
      simulate_static_season(user_strengths)
    else
      # Compute dynamic strengths for all clubs once
      opponent_strengths_map =
        Enum.into(clubs, %{}, fn club ->
          {club.id, calculate_opponent_strengths(club.id, season)}
        end)

      # Build 38 fixtures
      fixtures = build_fixtures(clubs)

      # Simulate matches for our team
      our_matches =
        Enum.reduce(
          Enum.with_index(fixtures, 1),
          %{week: 0, wins: 0, draws: 0, losses: 0, gf: 0, ga: 0, matches: []},
          fn {opponent, index}, acc ->
            opp_strengths = Map.fetch!(opponent_strengths_map, opponent.id)
            {result, gf, ga} = simulate_match_against_opponent(user_strengths, opp_strengths)

            match_detail = %{
              week: index,
              result: result,
              gf: gf,
              ga: ga,
              opponent: opponent.name,
              opponent_short: opponent.short_name
            }

            %{
              week: index,
              wins: acc.wins + if(result == :win, do: 1, else: 0),
              draws: acc.draws + if(result == :draw, do: 1, else: 0),
              losses: acc.losses + if(result == :loss, do: 1, else: 0),
              gf: acc.gf + gf,
              ga: acc.ga + ga,
              matches: acc.matches ++ [match_detail]
            }
          end
        )

      # Simulate all remaining non-user matches to build a complete league table
      # 20 teams total (User + 19 Opponents). Each plays 38 games.
      # Start with a map representing stats of each team.
      initial_table =
        Enum.into(
          clubs,
          %{
            "INV" => %{
              name: "INVINCIBLES",
              short: "INV",
              w: our_matches.wins,
              d: our_matches.draws,
              l: our_matches.losses,
              gf: our_matches.gf,
              ga: our_matches.ga,
              pts: our_matches.wins * 3 + our_matches.draws
            }
          },
          fn club ->
            # Count opponent's stats against us
            matches_against_us =
              Enum.filter(our_matches.matches, &(&1.opponent_short == club.short_name))

            # user loss = opponent win
            w = Enum.count(matches_against_us, &(&1.result == :loss))
            d = Enum.count(matches_against_us, &(&1.result == :draw))
            l = Enum.count(matches_against_us, &(&1.result == :win))
            gf = Enum.sum(Enum.map(matches_against_us, & &1.ga))
            ga = Enum.sum(Enum.map(matches_against_us, & &1.gf))

            {club.short_name,
             %{
               name: club.name,
               short: club.short_name,
               w: w,
               d: d,
               l: l,
               gf: gf,
               ga: ga,
               pts: w * 3 + d
             }}
          end
        )

      # Simulate remaining matches between opponents.
      # Each opponent plays every other opponent twice (home & away), minus the games against the User (which we already computed).
      opponents_list = Map.keys(initial_table) |> List.delete("INV")

      league_table_map =
        Enum.reduce(opponents_list, initial_table, fn t1, table_acc ->
          other_opps = List.delete(opponents_list, t1)

          Enum.reduce(other_opps, table_acc, fn t2, inner_table_acc ->
            # Only simulate if they haven't played their double-header matches yet.
            # We enforce an arbitrary sorting condition to avoid double simulating.
            if t1 < t2 do
              club1 = Enum.find(clubs, &(&1.short_name == t1))
              club2 = Enum.find(clubs, &(&1.short_name == t2))
              t1_strengths = Map.fetch!(opponent_strengths_map, club1.id)
              t2_strengths = Map.fetch!(opponent_strengths_map, club2.id)

              # Match 1 (t1 home)
              {res1, gf1, ga1} = simulate_match_against_opponent(t1_strengths, t2_strengths)
              # Match 2 (t2 home)
              {res2, gf2, ga2} = simulate_match_against_opponent(t2_strengths, t1_strengths)

              # Update stats for t1
              inner_table_acc =
                update_in(inner_table_acc, [t1], fn stats ->
                  w1 = if(res1 == :win, do: 1, else: 0) + if(res2 == :loss, do: 1, else: 0)
                  d1 = if(res1 == :draw, do: 1, else: 0) + if(res2 == :draw, do: 1, else: 0)
                  l1 = if(res1 == :loss, do: 1, else: 0) + if(res2 == :win, do: 1, else: 0)

                  stats
                  |> Map.update!(:w, &(&1 + w1))
                  |> Map.update!(:d, &(&1 + d1))
                  |> Map.update!(:l, &(&1 + l1))
                  |> Map.update!(:gf, &(&1 + gf1 + ga2))
                  |> Map.update!(:ga, &(&1 + ga1 + gf2))
                  |> Map.update!(:pts, &(&1 + w1 * 3 + d1))
                end)

              # Update stats for t2
              update_in(inner_table_acc, [t2], fn stats ->
                w2 = if(res1 == :loss, do: 1, else: 0) + if(res2 == :win, do: 1, else: 0)
                d2 = if(res1 == :draw, do: 1, else: 0) + if(res2 == :draw, do: 1, else: 0)
                l2 = if(res1 == :win, do: 1, else: 0) + if(res2 == :loss, do: 1, else: 0)

                stats
                |> Map.update!(:w, &(&1 + w2))
                |> Map.update!(:d, &(&1 + d2))
                |> Map.update!(:l, &(&1 + l2))
                |> Map.update!(:gf, &(&1 + ga1 + gf2))
                |> Map.update!(:ga, &(&1 + gf1 + ga2))
                |> Map.update!(:pts, &(&1 + w2 * 3 + d2))
              end)
            else
              inner_table_acc
            end
          end)
        end)

      # Sort the table by Pts (desc), then GD (desc), then GF (desc)
      sorted_table =
        Map.values(league_table_map)
        |> Enum.sort(fn a, b ->
          gd_a = a.gf - a.ga
          gd_b = b.gf - b.ga

          cond do
            a.pts != b.pts -> a.pts > b.pts
            gd_a != gd_b -> gd_a > gd_b
            a.gf != b.gf -> a.gf > b.gf
            true -> a.name < b.name
          end
        end)
        |> Enum.with_index(1)
        |> Enum.map(fn {team_stats, pos} -> Map.put(team_stats, :position, pos) end)

      our_matches
      |> Map.put(:season_label, season)
      |> Map.put(:league_table, sorted_table)
    end
  end

  # Select a random season from appearances in the DB
  defp select_random_season do
    seasons =
      from(a in Appearance,
        select: a.season,
        distinct: true
      )
      |> Repo.all()

    if Enum.empty?(seasons) do
      nil
    else
      Enum.random(seasons)
    end
  end

  # Fetch all unique clubs with appearances in a given season
  defp get_clubs_for_season(season) do
    from(c in Club,
      join: a in assoc(c, :appearances),
      where: a.season == ^season,
      distinct: true,
      select: c
    )
    |> Repo.all()
  end

  # Generates exactly 38 fixtures from the available clubs list
  defp build_fixtures(clubs) do
    Stream.repeatedly(fn -> Enum.random(clubs) end)
    |> Enum.take(38)
    |> Enum.shuffle()
  end

  # Calculates dynamic rating strength for an opponent club based on top players' stats
  defp calculate_opponent_strengths(club_id, season) do
    apps =
      from(a in Appearance,
        join: p in assoc(a, :player),
        where: a.club_id == ^club_id and a.season == ^season,
        order_by: [desc: a.ovr],
        preload: [:player]
      )
      |> Repo.all()

    # Group top players by position to calculate strengths
    gks = Enum.filter(apps, &(&1.player.primary_position == "GK")) |> Enum.take(1)
    dfs = Enum.filter(apps, &(&1.player.primary_position == "DF")) |> Enum.take(4)
    mfs = Enum.filter(apps, &(&1.player.primary_position == "MF")) |> Enum.take(4)
    fws = Enum.filter(apps, &(&1.player.primary_position == "FW")) |> Enum.take(2)

    lineup = %{
      gk: List.first(gks),
      lb: Enum.at(dfs, 0),
      cb1: Enum.at(dfs, 1),
      cb2: Enum.at(dfs, 2),
      rb: Enum.at(dfs, 3),
      lm: Enum.at(mfs, 0),
      cm: Enum.at(mfs, 1),
      rm: Enum.at(mfs, 2),
      cm1: Enum.at(mfs, 3),
      lw: Enum.at(fws, 0),
      st: Enum.at(fws, 1)
    }

    calculate_strengths(lineup)
  end

  # Simulates match against specific opponent strengths
  defp simulate_match_against_opponent(user_strengths, opp_strengths) do
    {user_goals, opp_goals} =
      Enum.reduce(1..5, {0, 0}, fn _possession, {u_goals, o_goals} ->
        user_variance = 0.7 + :rand.uniform() * 0.6
        opp_variance = 0.7 + :rand.uniform() * 0.6

        user_control = user_strengths.control * user_variance
        opp_control = opp_strengths.control * opp_variance

        if user_control >= opp_control do
          if score_check?(user_strengths.attack, opp_strengths.defense, opp_strengths.gk) do
            {u_goals + 1, o_goals}
          else
            {u_goals, o_goals}
          end
        else
          if score_check?(opp_strengths.attack, user_strengths.defense, user_strengths.gk) do
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
end
