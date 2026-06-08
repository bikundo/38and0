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

    # Bias: 70% chance of choosing a Top 6 club, 30% chance of any club.
    # To keep draft quality high, we only select club/seasons with at least 5 players of OVR >= 80.
    use_top_6? = :rand.uniform(100) <= 70

    query =
      if use_top_6? do
        from(a in Appearance,
          join: c in assoc(a, :club),
          where: a.ovr >= 80 and c.name in ^top_6_names,
          group_by: [a.club_id, a.season, c.id],
          having: count(a.id) >= 5,
          select: {a.club_id, a.season},
          order_by: fragment("RANDOM()"),
          limit: 1
        )
      else
        from(a in Appearance,
          join: c in assoc(a, :club),
          where: a.ovr >= 80,
          group_by: [a.club_id, a.season, c.id],
          having: count(a.id) >= 5,
          select: {a.club_id, a.season},
          order_by: fragment("RANDOM()"),
          limit: 1
        )
      end

    case Repo.one(query) do
      nil ->
        # Fallback to unrestricted search if query is empty or db not ready
        fallback_query =
          from(a in Appearance,
            join: c in assoc(a, :club),
            order_by: fragment("RANDOM()"),
            limit: 1,
            preload: [:club]
          )

        case Repo.one(fallback_query) do
          nil -> {:error, :no_data}
          app -> fetch_appearances_for_spin(app.club, app.season)
        end

      {club_id, season} ->
        club = Repo.get!(Invincibles.Game.Club, club_id)
        fetch_appearances_for_spin(club, season)
    end
  end

  defp fetch_appearances_for_spin(club, season) do
    # Fetch appearances for that club and season (OVR >= 80 only, big-name players)
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
  """
  def auto_draft_lineup(
        lineup,
        active_slots \\ [:gk, :lb, :cb1, :cb2, :rb, :lm, :cm, :rm, :lw, :st, :rw]
      ) do
    # Map each slot to its preferred specific position key(s)
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

    Enum.reduce(active_slots, {lineup, []}, fn slot, {current_lineup, drafted_ids} ->
      # Accumulate all drafted player IDs from current lineup and local list
      all_drafted =
        (Enum.map(current_lineup, fn {_, app} -> if app, do: app.player_id, else: nil end) ++
           drafted_ids)
        |> Enum.reject(&is_nil/1)

      if is_nil(Map.get(current_lineup, slot)) do
        category =
          cond do
            slot == :gk -> "GK"
            slot in [:lb, :cb1, :cb2, :cb3, :rb] -> "DF"
            slot in [:lm, :cm, :cm1, :cm2, :cm3, :rm] -> "MF"
            slot in [:lw, :st, :st1, :st2, :rw] -> "FW"
          end

        preferred_specs = Map.get(slot_preferences, slot, [])

        # Fetch 30 random candidates from the DB for this category
        base_candidates =
          from(a in Appearance,
            join: p in assoc(a, :player),
            where:
              a.ovr >= 80 and p.primary_position == ^category and a.player_id not in ^all_drafted,
            order_by: fragment("RANDOM()"),
            limit: 30,
            preload: [:player, :club]
          )
          |> Repo.all()

        # Try to find candidates matching preferred sub-positions
        specific_candidates =
          base_candidates
          |> Enum.filter(fn app ->
            get_specific_position(app.player.display_name) in preferred_specs
          end)

        # Step 3: Choose from specific matching, or fall back to any candidate of general category
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
      else
        {current_lineup, drafted_ids}
      end
    end)
    |> elem(0)
  end

  # Helper to identify player's natural sub-position based on name keywords
  defp get_specific_position(name) do
    name_lower = String.downcase(name)

    cond do
      String.contains?(name_lower, [
        "ederson",
        "alisson",
        "cech",
        "schmeichel",
        "seaman",
        "lehmann",
        "van der sar",
        "de gea",
        "courtois",
        "lloris",
        "reina",
        "hart",
        "james",
        "barthez",
        "dudek",
        "howard",
        "friedel",
        "robinson",
        "martyn",
        "gk",
        "goalkeeper"
      ]) ->
        :gk

      String.contains?(name_lower, [
        "ashley cole",
        "robertson",
        "irwin",
        "evra",
        "riise",
        "baines",
        "luke shaw",
        "clichy",
        "bridge",
        "le saux",
        "chilwell",
        "marcos alonso",
        "babayaro",
        "zinchenko",
        "estupinan",
        "gvardiol",
        "aké",
        "ake",
        "left-back",
        "left back",
        "lb"
      ]) ->
        :lb

      String.contains?(name_lower, [
        "gary neville",
        "walker",
        "alexander-arnold",
        "ivanovic",
        "sagna",
        "lauren",
        "zabaleta",
        "azpilicueta",
        "coleman",
        "trippier",
        "reece james",
        "wan-bissaka",
        "glen johnson",
        "ferreira",
        "finnan",
        "petrescu",
        "steve carr",
        "lee dixon",
        "white",
        "porro",
        "right-back",
        "right back",
        "rb"
      ]) ->
        :rb

      String.contains?(name_lower, [
        "van dijk",
        "terry",
        "ferdinand",
        "vidic",
        "sol campbell",
        "tony adams",
        "jaap stam",
        "kompany",
        "carvalho",
        "hyypia",
        "carragher",
        "ledley king",
        "pallister",
        "steve bruce",
        "keown",
        "bould",
        "saliba",
        "gabriel",
        "ruben dias",
        "dias",
        "stones",
        "laporte",
        "toure",
        "skrtel",
        "agger",
        "morgan",
        "huth",
        "alderweireld",
        "vertonghen",
        "desailly",
        "leboeuf",
        "david luiz",
        "cahill",
        "thiago silva",
        "rudiger",
        "konate",
        "romero",
        "botman",
        "martinez",
        "varane",
        "maguire",
        "lindelof",
        "mertesacker",
        "koscielny",
        "centre-back",
        "centre back",
        "cb",
        "defender"
      ]) ->
        :cb

      String.contains?(name_lower, [
        "giggs",
        "pires",
        "duff",
        "kewell",
        "overmars",
        "gareth bale",
        "bale",
        "eden hazard",
        "hazard",
        "son heung-min",
        "son",
        "rashford",
        "sterling",
        "grealish",
        "martinelli",
        "luis diaz",
        "sadio mane",
        "mane",
        "sancho",
        "zaha",
        "foden",
        "barnes",
        "mitoma",
        "mudryk",
        "winger",
        "left winger",
        "lw"
      ]) ->
        :lw

      String.contains?(name_lower, [
        "beckham",
        "cristiano ronaldo",
        "ronaldo",
        "ljungberg",
        "anderton",
        "solano",
        "mcmanaman",
        "wright-phillips",
        "lennon",
        "mahrez",
        "saka",
        "kulusevski",
        "bernardo silva",
        "salah",
        "raphinha",
        "antony",
        "bowen",
        "almiron",
        "dembele",
        "right winger",
        "rw"
      ]) ->
        :rw

      String.contains?(name_lower, [
        "henry",
        "shearer",
        "wayne rooney",
        "rooney",
        "nistelrooy",
        "drogba",
        "sergio aguero",
        "aguero",
        "kane",
        "van persie",
        "suarez",
        "fowler",
        "andy cole",
        "dwight yorke",
        "sheringham",
        "zola",
        "bergkamp",
        "cantona",
        "owen",
        "robbie keane",
        "keane",
        "defoe",
        "hasselbaink",
        "anelka",
        "torres",
        "berbatov",
        "tevez",
        "giroud",
        "firmino",
        "haaland",
        "gabriel jesus",
        "jesus",
        "isak",
        "watkins",
        "nunez",
        "mitrovic",
        "toney",
        "aubameyang",
        "lukaku",
        "vardy",
        "costa",
        "benteke",
        "adebayor",
        "striker",
        "forward",
        "st",
        "cf"
      ]) ->
        :st

      true ->
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
  Fetches a share record. Automatically checks if the record has expired (48 hours).
  If expired, deletes it and returns :error.
  Otherwise reconstructs the lineup with preloaded appearances.
  """
  def get_share(id) do
    case Repo.get(Share, id) do
      nil ->
        :error

      share ->
        inserted_at = DateTime.from_naive!(share.inserted_at, "Etc/UTC")
        diff_seconds = DateTime.diff(DateTime.utc_now(), inserted_at)

        if diff_seconds >= 172_800 do
          Repo.delete(share)
          :error
        else
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
  end

  @doc """
  Lists all active shares created within the last 48 hours, sorted by:
  1. Points (wins * 3 + draws) desc
  2. Losses asc
  3. Goal Difference desc
  4. Wins desc
  5. Recency desc
  """
  def list_active_shares do
    two_days_ago_naive = NaiveDateTime.utc_now() |> NaiveDateTime.add(-172_800, :second)

    from(s in Share,
      where: s.inserted_at > ^two_days_ago_naive,
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
end
