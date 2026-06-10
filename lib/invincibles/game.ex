defmodule Invincibles.Game do
  @moduledoc """
  Context module for managing clubs, players, and appearances.
  """
  import Ecto.Query
  alias Invincibles.Repo
  alias Invincibles.Game.Appearance

  @doc """
  Randomly selects a club and season from existing database appearances,
  then returns all appearances matching that club and season.
  Preloads the associated player and club.
  """
  def spin_wheel do
    top_6_names = [
      "Arsenal",
      "Manchester United",
      "Chelsea",
      "Liverpool",
      "Manchester City",
      "Tottenham Hotspur"
    ]

    use_top_6? = :rand.uniform(100) <= 70

    query =
      if use_top_6? do
        from(a in Appearance,
          join: c in assoc(a, :club),
          where: a.ovr >= 80 and c.name in ^top_6_names,
          group_by: [a.club_id, a.season, c.id],
          having: count(a.id) >= 5,
          select: {a.club_id, a.season}
        )
      else
        from(a in Appearance,
          join: c in assoc(a, :club),
          where: a.ovr >= 80,
          group_by: [a.club_id, a.season, c.id],
          having: count(a.id) >= 5,
          select: {a.club_id, a.season}
        )
      end

    valid_pairs = Repo.all(query)

    case valid_pairs do
      [] ->
        count = Repo.aggregate(Appearance, :count, :id)

        if count == 0 do
          {:error, :no_data}
        else
          offset = :rand.uniform(count) - 1

          app =
            from(a in Appearance,
              offset: ^offset,
              limit: 1,
              preload: [:club]
            )
            |> Repo.one()

          case app do
            nil -> {:error, :no_data}
            app -> fetch_appearances_for_spin(app.club, app.season)
          end
        end

      pairs ->
        {club_id, season} = Enum.random(pairs)
        club = Repo.get!(Invincibles.Game.Club, club_id)
        fetch_appearances_for_spin(club, season)
    end
  end

  defp fetch_appearances_for_spin(club, season) do
    appearances =
      from(a in Appearance,
        where: a.club_id == ^club.id and a.season == ^season and a.ovr >= 80,
        order_by: a.ovr,
        preload: [:player, :club]
      )
      |> Repo.all()

    {:ok, club, season, appearances}
  end

  @doc """
  Fetches an appearance by ID.
  """
  def get_appearance(id) do
    Repo.get(Appearance, id) |> Repo.preload([:player, :club])
  end

  @doc """
  Calculates the draft cost of a player based on their OVR rating.
  - OVR >= 90: Premium Legend (40M - 80M)
  - OVR 83-89: Rare Gold (15M - 33M)
  - OVR < 83: Common Silver/Slate (5M - 15M)
  """
  def calculate_cost(ovr) do
    cond do
      ovr >= 90 ->
        40_000_000 + (ovr - 90) * 8_000_000

      ovr >= 83 ->
        15_000_000 + (ovr - 83) * 3_000_000

      true ->
        5_000_000 + (ovr - 50) * 300_000
    end
  end

  @doc """
  Automatically fills any empty positions in the lineup with high-quality (OVR >= 80) players.
  Fetches all draftable candidates in a single query, then assigns positions in memory.
  """
  def auto_draft_lineup(
        lineup,
        active_slots \\ [:gk, :lb, :cb1, :cb2, :rb, :lm, :cm, :rm, :lw, :st, :rw]
      ) do
    slot_preferences = %{
      gk: [:gk],
      lb: [:lb],
      rb: [:rb],
      cb1: [:cb],
      cb2: [:cb],
      cb3: [:cb],
      lm: [:lw, :cm],
      rm: [:rw, :cm],
      cm: [:cm],
      cm1: [:cm],
      cm2: [:cm],
      cm3: [:cm],
      lw: [:lw],
      rw: [:rw],
      st: [:st],
      st1: [:st],
      st2: [:st]
    }

    already_drafted =
      Enum.map(lineup, fn {_, app} -> if app, do: app.player_id, else: nil end)
      |> Enum.reject(&is_nil/1)

    empty_slots = Enum.filter(active_slots, fn slot -> is_nil(Map.get(lineup, slot)) end)

    if Enum.empty?(empty_slots) do
      lineup
    else
      needed_categories =
        Enum.map(empty_slots, fn slot ->
          cond do
            slot == :gk -> "GK"
            slot in [:lb, :cb1, :cb2, :cb3, :rb] -> "DF"
            slot in [:lm, :cm, :cm1, :cm2, :cm3, :rm] -> "MF"
            slot in [:lw, :st, :st1, :st2, :rw] -> "FW"
          end
        end)
        |> Enum.uniq()

      all_candidates =
        from(a in Appearance,
          join: p in assoc(a, :player),
          where:
            a.ovr >= 80 and p.primary_position in ^needed_categories and
              a.player_id not in ^already_drafted,
          preload: [:player, :club]
        )
        |> Repo.all()
        |> Enum.shuffle()

      candidates_by_category = Enum.group_by(all_candidates, & &1.player.primary_position)

      Enum.reduce(empty_slots, {lineup, already_drafted}, fn slot,
                                                             {current_lineup, drafted_ids} ->
        category =
          cond do
            slot == :gk -> "GK"
            slot in [:lb, :cb1, :cb2, :cb3, :rb] -> "DF"
            slot in [:lm, :cm, :cm1, :cm2, :cm3, :rm] -> "MF"
            slot in [:lw, :st, :st1, :st2, :rw] -> "FW"
          end

        preferred_specs = Map.get(slot_preferences, slot, [])

        base_candidates =
          Map.get(candidates_by_category, category, [])
          |> Enum.reject(fn app -> app.player_id in drafted_ids end)
          |> Enum.take(30)

        specific_candidates =
          base_candidates
          |> Enum.filter(fn app ->
            infer_sub_position(app) in preferred_specs
          end)

        final_candidates =
          if Enum.empty?(specific_candidates) do
            base_candidates
          else
            specific_candidates
          end

        case final_candidates do
          [] ->
            {current_lineup, drafted_ids}

          list ->
            chosen = Enum.random(list)
            {Map.put(current_lineup, slot, chosen), [chosen.player_id | drafted_ids]}
        end
      end)
      |> elem(0)
    end
  end

  defp infer_sub_position(appearance) do
    pos = appearance.player.primary_position
    stats = appearance.stats || %{}

    case pos do
      "GK" ->
        :gk

      "DF" ->
        pac = Map.get(stats, "pac", 50)
        def_stat = Map.get(stats, "def", 50)
        phy = Map.get(stats, "phy", 50)

        if pac > (def_stat + phy) / 2 do
          if rem(appearance.id, 2) == 0, do: :lb, else: :rb
        else
          :cb
        end

      "MF" ->
        :cm

      "FW" ->
        sho = Map.get(stats, "sho", 50)
        pac = Map.get(stats, "pac", 50)
        dri = Map.get(stats, "dri", 50)

        if sho >= pac and sho >= dri do
          :st
        else
          if rem(appearance.id, 2) == 0, do: :lw, else: :rw
        end

      _ ->
        :cm
    end
  end

  alias Invincibles.Game.Share

  @doc """
  Creates a share record, serializing the lineup map to slot name => appearance ID.
  """
  def create_share(lineup, formation, season_record, season_label, funny_quote) do
    lineup_ids =
      Enum.reduce(lineup, %{}, fn {slot, app}, acc ->
        case app do
          nil -> Map.put(acc, Atom.to_string(slot), nil)
          %Appearance{id: id} -> Map.put(acc, Atom.to_string(slot), id)
        end
      end)

    %Share{}
    |> Share.changeset(%{
      formation: formation,
      lineup: lineup_ids,
      season_record: season_record,
      season_label: season_label,
      funny_quote: funny_quote
    })
    |> Repo.insert()
  end

  @doc """
  Fetches a share record and reconstructs the lineup with preloaded appearances.
  """
  def get_share(id) do
    case Repo.get(Share, id) do
      nil ->
        :error

      share ->
        app_ids =
          share.lineup
          |> Map.values()
          |> Enum.reject(&is_nil/1)

        appearances =
          from(a in Appearance,
            where: a.id in ^app_ids,
            preload: [:player, :club]
          )
          |> Repo.all()
          |> Map.new(fn app -> {app.id, app} end)

        reconstructed_lineup =
          Enum.reduce(share.lineup, %{}, fn {slot_str, app_id}, acc ->
            slot_atom = String.to_existing_atom(slot_str)
            app_struct = if app_id, do: Map.get(appearances, app_id), else: nil
            Map.put(acc, slot_atom, app_struct)
          end)

        season_record_atoms =
          Map.new(share.season_record, fn {k, v} -> {String.to_existing_atom(k), v} end)

        {:ok, %{share | lineup: reconstructed_lineup, season_record: season_record_atoms}}
    end
  end

  @doc """
  Lists the best shares of all time, sorted by:
  1. Points (wins * 3 + draws) desc
  2. Losses asc
  3. Goal Difference desc
  4. Wins desc
  5. Recency desc
  """
  def list_active_shares do
    from(s in Share,
      order_by: [
        desc:
          fragment(
            "coalesce((?->>'wins')::integer, 0) * 3 + coalesce((?->>'draws')::integer, 0)",
            s.season_record,
            s.season_record
          ),
        asc: fragment("coalesce((?->>'losses')::integer, 0)", s.season_record),
        desc:
          fragment(
            "coalesce((?->>'gf')::integer, 0) - coalesce((?->>'ga')::integer, 0)",
            s.season_record,
            s.season_record
          ),
        desc: fragment("coalesce((?->>'wins')::integer, 0)", s.season_record),
        desc: s.inserted_at
      ],
      limit: 20
    )
    |> Repo.all()
  end

  @doc """
  Counts the total number of shared game records in the database.
  """
  def count_all_shares do
    Repo.aggregate(Share, :count, :id)
  end

  @doc """
  Lists all clubs in alphabetical order.
  """
  def list_all_clubs do
    from(c in Invincibles.Game.Club, order_by: c.name)
    |> Repo.all()
  end

  @doc """
  Lists all unique seasons for which a club has appearances.
  """
  def list_seasons_for_club(club_id) do
    from(a in Appearance,
      where: a.club_id == ^club_id,
      group_by: a.season,
      select: a.season,
      order_by: [desc: a.season]
    )
    |> Repo.all()
  end

  @doc """
  Lists all appearances for a club in a specific season, sorted by rating (desc).
  """
  def list_appearances_for_club_and_season(club_id, season) do
    from(a in Appearance,
      where: a.club_id == ^club_id and a.season == ^season,
      order_by: [desc: a.ovr],
      preload: [:player, :club]
    )
    |> Repo.all()
  end

  @doc """
  Lists appearances for a club in a specific season with OVR >= 80, sorted by OVR (asc/desc as required by the draft).
  """
  def list_appearances_for_spin(club_id, season) do
    appearances =
      from(a in Appearance,
        where: a.club_id == ^club_id and a.season == ^season and a.ovr >= 80,
        preload: [:player, :club]
      )
      |> Repo.all()

    pos_weight = fn
      "GK" -> 1
      "DF" -> 2
      "MF" -> 3
      "FW" -> 4
      _ -> 5
    end

    Enum.sort_by(appearances, fn app ->
      {pos_weight.(app.player.primary_position), app.player.name}
    end)
  end
end
