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

    # 1. Fetch a random appearance from the DB to get a valid club + season (Top 6 only)
    random_app =
      from(a in Appearance,
        join: c in assoc(a, :club),
        where: c.name in ^top_6_names,
        order_by: fragment("RANDOM()"),
        limit: 1,
        preload: [:club]
      )
      |> Repo.one()

    case random_app do
      nil ->
        {:error, :no_data}

      app ->
        club = app.club
        season = app.season

        # 2. Fetch appearances for that club and season (OVR >= 80 only, big-name players)
        appearances =
          from(a in Appearance,
            where: a.club_id == ^club.id and a.season == ^season and a.ovr >= 80,
            order_by: a.ovr,
            preload: [:player, :club]
          )
          |> Repo.all()

        {:ok, club, season, appearances}
    end
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
end
