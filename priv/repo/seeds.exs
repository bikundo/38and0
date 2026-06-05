defmodule Seeds do
  alias Invincibles.Repo
  alias Invincibles.Game.Club
  alias Invincibles.Game.Player
  alias Invincibles.Game.Appearance

  # Static metadata mapping for real clubs to short names, colors, and default fallback base ratings
  @clubs_metadata %{
    "Arsenal" => %{short_name: "ARS", color: "#EF4444", base_rating: 86},
    "Manchester United" => %{short_name: "MUN", color: "#DC2626", base_rating: 87},
    "Chelsea" => %{short_name: "CHE", color: "#2563EB", base_rating: 84},
    "Liverpool" => %{short_name: "LIV", color: "#B91C1C", base_rating: 85},
    "Manchester City" => %{short_name: "MCI", color: "#0EA5E9", base_rating: 80},
    "Blackburn Rovers" => %{short_name: "BLB", color: "#3B82F6", base_rating: 82},
    "Tottenham Hotspur" => %{short_name: "TOT", color: "#1E293B", base_rating: 83},
    "Newcastle United" => %{short_name: "NEW", color: "#0F172A", base_rating: 82},
    "Aston Villa" => %{short_name: "AVL", color: "#94113B", base_rating: 79},
    "Everton" => %{short_name: "EVE", color: "#0000FF", base_rating: 79},
    "West Ham United" => %{short_name: "WHU", color: "#7C2D12", base_rating: 78},
    "Leicester City" => %{short_name: "LEI", color: "#1E3A8A", base_rating: 77},
    "Leeds United" => %{short_name: "LEE", color: "#FBBF24", base_rating: 80},
    "Southampton" => %{short_name: "SOU", color: "#EF4444", base_rating: 76},
    "Middlesbrough" => %{short_name: "MID", color: "#B91C1C", base_rating: 77},
    "Fulham" => %{short_name: "FUL", color: "#FFFFFF", base_rating: 76},
    "Crystal Palace" => %{short_name: "CRY", color: "#1D4ED8", base_rating: 75},
    "Wolverhampton Wanderers" => %{short_name: "WOL", color: "#F59E0B", base_rating: 76},
    "West Bromwich Albion" => %{short_name: "WBA", color: "#0F172A", base_rating: 74},
    "Sunderland" => %{short_name: "SUN", color: "#DC2626", base_rating: 75},
    "Bolton Wanderers" => %{short_name: "BOL", color: "#E2E8F0", base_rating: 77},
    "Portsmouth" => %{short_name: "POR", color: "#1E3A8A", base_rating: 76},
    "Charlton Athletic" => %{short_name: "CHA", color: "#EF4444", base_rating: 75},
    "Wigan Athletic" => %{short_name: "WIG", color: "#3B82F6", base_rating: 75},
    "Stoke City" => %{short_name: "STK", color: "#EF4444", base_rating: 76},
    "Swansea City" => %{short_name: "SWA", color: "#FFFFFF", base_rating: 76},
    "Norwich City" => %{short_name: "NOR", color: "#EAB308", base_rating: 74},
    "Watford" => %{short_name: "WAT", color: "#EAB308", base_rating: 74},
    "Brentford" => %{short_name: "BRE", color: "#DC2626", base_rating: 76},
    "Brighton and Hove Albion" => %{short_name: "BHA", color: "#1D4ED8", base_rating: 78},
    "Coventry City" => %{short_name: "CC", color: "#60A5FA", base_rating: 76},
    "Queens Park Rangers" => %{short_name: "QPR", color: "#3B82F6", base_rating: 76},
    "Nottingham Forest" => %{short_name: "NFO", color: "#EF4444", base_rating: 76},
    "Sheffield Wednesday" => %{short_name: "SW", color: "#1E3A8A", base_rating: 76},
    "Wimbledon (- 2004)" => %{short_name: "WIM", color: "#FBBF24", base_rating: 76},
    "Ipswich Town" => %{short_name: "IPS", color: "#2563EB", base_rating: 76},
    "Derby County" => %{short_name: "DER", color: "#FFFFFF", base_rating: 76},
    "Oldham Athletic" => %{short_name: "OLD", color: "#2563EB", base_rating: 73},
    "Swindon Town" => %{short_name: "SWI", color: "#EF4444", base_rating: 72},
    "Barnsley" => %{short_name: "BAR", color: "#DC2626", base_rating: 73},
    "Bradford City" => %{short_name: "BRA", color: "#F59E0B", base_rating: 74},
    "Birmingham City" => %{short_name: "BIR", color: "#1E3A8A", base_rating: 76},
    "Reading" => %{short_name: "REA", color: "#2563EB", base_rating: 76},
    "Hull City" => %{short_name: "HUL", color: "#FBBF24", base_rating: 75},
    "Blackpool" => %{short_name: "BLA", color: "#F97316", base_rating: 74},
    "Cardiff City" => %{short_name: "CAR", color: "#2563EB", base_rating: 75},
    "AFC Bournemouth" => %{short_name: "BOU", color: "#DC2626", base_rating: 76},
    "Huddersfield Town" => %{short_name: "HUD", color: "#60A5FA", base_rating: 75},
    "Luton Town" => %{short_name: "LUT", color: "#F97316", base_rating: 75},
    "Sheffield United" => %{short_name: "SHU", color: "#EF4444", base_rating: 75},
    "Burnley" => %{short_name: "BUR", color: "#B91C1C", base_rating: 76}
  }

  def run do
    dataset_path = "/Users/bix/Downloads/archive/DATA_JSON"
    stats_csv_path = "stats/seasonstats.csv"

    # 1. Clear database
    IO.puts("Clearing existing database tables...")
    Repo.delete_all(Appearance)
    Repo.delete_all(Player)
    Repo.delete_all(Club)

    # 2. Parse CSV stats points
    IO.puts("Parsing season points from stats/seasonstats.csv...")
    teams_points = parse_season_stats(stats_csv_path)

    # 3. Iterate and build dynamic clubs list from files
    IO.puts("Scanning dataset files to create clubs...")

    seasons_dirs =
      File.ls!(dataset_path)
      # Filter for Season_XXXX
      |> Enum.filter(&String.starts_with?(&1, "Season_"))
      |> Enum.sort()

    club_names = find_all_club_names(dataset_path, seasons_dirs)

    club_map =
      Enum.into(club_names, %{}, fn raw_name ->
        clean_name = clean_club_name(raw_name)

        meta =
          Map.get(@clubs_metadata, clean_name, %{
            short_name: default_short_name(clean_name),
            color: "#64748B",
            base_rating: 75
          })

        club =
          case Repo.get_by(Club, name: clean_name) do
            nil ->
              Repo.insert!(
                Club.changeset(%Club{}, %{
                  name: clean_name,
                  short_name: meta.short_name,
                  primary_color: meta.color
                })
              )

            existing ->
              existing
          end

        {raw_name, %{id: club.id, name: club.name, base_rating: meta.base_rating}}
      end)

    IO.puts("Successfully inserted #{map_size(club_map)} clubs.")

    # 4. Seed players and appearances season by season
    for season_dir <- seasons_dirs do
      "Season_" <> year_str = season_dir
      year = String.to_integer(year_str)
      season_label = "#{year}-#{year + 1}"
      csv_season_key = "#{year}/#{year + 1}"

      IO.puts("Seeding season #{season_label}...")
      season_path = Path.join(dataset_path, season_dir)

      json_files =
        File.ls!(season_path)
        |> Enum.filter(&String.ends_with?(&1, ".json"))

      for file <- json_files do
        raw_club_name = parse_club_name_from_filename(file)
        club_info = Map.fetch!(club_map, raw_club_name)

        # Lookup points for this club in this season to calculate dynamic club rating
        csv_club_key = map_to_csv_team_name(club_info.name)
        pts = Map.get(teams_points, {csv_season_key, csv_club_key}, 50)

        # Calculate dynamic club base rating from points (30-100 points mapped to 72-88 rating)
        dynamic_club_rating = 70 + floor((pts - 15) * 0.25)
        dynamic_club_rating = max(min(dynamic_club_rating, 90), 72)

        # Read file content
        file_path = Path.join(season_path, file)
        {:ok, json_text} = File.read(file_path)
        {:ok, squad_data} = Jason.decode(json_text)

        players_data = Map.get(squad_data, "players", [])

        # Process each player in squad
        for player_data <- players_data do
          full_name = player_data["name"] |> String.trim()
          raw_pos = player_data["position"]
          pos_group = map_position_group(raw_pos)
          display_name = make_display_name(full_name)

          # 1. Get or create Player
          player =
            case Repo.get_by(Player, name: full_name) do
              nil ->
                Repo.insert!(
                  Player.changeset(%Player{}, %{
                    name: full_name,
                    display_name: display_name,
                    primary_position: pos_group
                  })
                )

              existing ->
                existing
            end

          # 2. Determine player OVR rating based on market value, or age, or team strength
          ovr = calculate_player_ovr(player_data, dynamic_club_rating)

          # 3. Generate stats based on position and rating
          stats =
            if pos_group == "GK" do
              gen_gk_stats(ovr)
            else
              gen_outfield_stats(pos_group, ovr)
            end

          era =
            cond do
              year < 2000 -> "90s"
              year < 2010 -> "00s"
              year < 2020 -> "10s"
              true -> "20s"
            end

          # 4. Create appearance
          case Repo.get_by(Appearance, player_id: player.id, season: season_label) do
            nil ->
              Repo.insert!(
                Appearance.changeset(%Appearance{}, %{
                  player_id: player.id,
                  club_id: club_info.id,
                  season: season_label,
                  era: era,
                  ovr: ovr,
                  stats: stats
                })
              )

            _exists ->
              nil
          end
        end
      end
    end

    total_apps = Repo.aggregate(Appearance, :count)
    total_players = Repo.aggregate(Player, :count)

    IO.puts(
      "Successfully seeded #{total_players} real players with #{total_apps} appearances since 1992!"
    )
  end

  # Parse season points stats CSV
  defp parse_season_stats(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        # Drop header
        |> Enum.drop(1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.reduce(%{}, fn line, acc ->
          # CSV format: id,Season,Squad,W,D,L,GF,GA,Pts,...
          parts = String.split(line, ",")

          if length(parts) >= 9 do
            season = Enum.at(parts, 1)
            raw_squad = Enum.at(parts, 2)
            pts_str = Enum.at(parts, 8)

            squad_key =
              String.downcase(raw_squad)
              |> String.replace("united", "utd")
              |> String.replace("wednesday", "weds")
              |> String.replace("athletic", "ath")
              |> String.replace("nottingham", "nott'ham")

            case Integer.parse(pts_str) do
              {pts, _} -> Map.put(acc, {season, squad_key}, pts)
              _ -> acc
            end
          else
            acc
          end
        end)

      _ ->
        %{}
    end
  end

  # Map real club name to CSV normalized squad name
  defp map_to_csv_team_name(name) do
    norm =
      String.downcase(name)
      |> String.replace("united", "utd")
      |> String.replace("wednesday", "weds")
      |> String.replace("athletic", "ath")
      |> String.replace("nottingham", "nott'ham")

    cond do
      norm == "queens park rangers" -> "qpr"
      norm == "wolverhampton wanderers" -> "wolves"
      norm == "wimbledon (- 2004)" -> "wimbledon"
      true -> norm
    end
  end

  # Find all unique club names from JSON filenames across all seasons
  defp find_all_club_names(dataset_path, seasons_dirs) do
    Enum.reduce(seasons_dirs, MapSet.new(), fn dir, acc ->
      dir_path = Path.join(dataset_path, dir)

      File.ls!(dir_path)
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.map(&parse_club_name_from_filename/1)
      |> Enum.reduce(acc, &MapSet.put(&2, &1))
    end)
  end

  # Parse raw club name from filename (e.g., Arsenal_FC_11_1992.json -> Arsenal FC)
  defp parse_club_name_from_filename(filename) do
    parts = String.split(filename, "_")
    id_idx = Enum.find_index(parts, fn part -> String.match?(part, ~r/^\d+$/) end)

    if id_idx do
      Enum.take(parts, id_idx) |> Enum.join(" ")
    else
      String.replace(filename, ~r/_\d+_\d+\.json$/, "") |> String.replace("_", " ")
    end
  end

  # Clean club name to match our metadata naming conventions
  defp clean_club_name(raw_name) do
    raw_name
    |> String.replace(~r/\s+FC$/, "")
    |> String.replace(~r/\s+AFC$/, "")
    |> String.replace(~r/\s+Association Football Club$/, "")
    |> String.replace(~r/\s+Football Club$/, "")
    |> String.replace(~r/\s+Association$/, "")
    |> String.trim()
  end

  # Default short name generator
  defp default_short_name(name) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
    |> String.slice(0, 4)
  end

  # Convert raw position to GK, DF, MF, FW
  defp map_position_group(pos) do
    cond do
      pos == "Goalkeeper" ->
        "GK"

      pos in ["Centre-Back", "Left-Back", "Right-Back", "Defender", "Sweeper"] ->
        "DF"

      pos in [
        "Central Midfield",
        "Defensive Midfield",
        "Attacking Midfield",
        "Left Midfield",
        "Right Midfield",
        "Midfielder"
      ] ->
        "MF"

      pos in ["Centre-Forward", "Second Striker", "Striker", "Left Winger", "Right Winger"] ->
        "FW"

      true ->
        "MF"
    end
  end

  # Display name format: "D. Seaman", "T. Adams"
  defp make_display_name(full_name) do
    parts = String.split(full_name)

    case parts do
      [] -> ""
      [single] -> single
      [first | rest] -> String.first(first) <> ". " <> List.last(rest)
    end
  end

  # OVR Rating calculation based on marketValue, age, base_rating
  defp calculate_player_ovr(player_data, club_base_rating) do
    base = club_base_rating
    mv_str = player_data["marketValue"]

    mv_modifier =
      if mv_str && mv_str != "None" do
        cleaned = String.replace(mv_str, "€", "") |> String.trim()

        val =
          cond do
            String.ends_with?(cleaned, "m") ->
              {num, _} = Float.parse(String.replace(cleaned, "m", ""))
              num * 1_000_000

            String.ends_with?(cleaned, "k") ->
              {num, _} = Float.parse(String.replace(cleaned, "k", ""))
              num * 1_000

            true ->
              case Float.parse(cleaned) do
                {num, _} -> num
                _ -> 0.0
              end
          end

        # More conservative market value scaling to prevent inflated ratings:
        # e.g., 100M+ = +10, 60M = +7, 35M = +4, 20M = +2, 10M = +1, 5M = +0, 2M = -2, 1M = -4, <1M = -6
        cond do
          val >= 100_000_000 -> 10
          val >= 60_000_000 -> 7
          val >= 35_000_000 -> 4
          val >= 20_000_000 -> 2
          val >= 10_000_000 -> 1
          val >= 5_000_000 -> 0
          val >= 2_000_000 -> -2
          val >= 1_000_000 -> -4
          true -> -6
        end
      else
        age =
          case Integer.parse(Map.get(player_data, "age") || "") do
            {val, _} -> val
            _ -> 25
          end

        cond do
          age in 24..29 -> 2
          age < 21 -> -3
          age > 33 -> -2
          true -> 0
        end
      end

    # Deterministic pseudo-random variance based on player name hash
    hash = :erlang.phash2(player_data["name"])
    # -3 to +3
    variance = rem(hash, 7) - 3

    clamp(base + mv_modifier + variance, 60, 97)
  end

  defp gen_outfield_stats(pos, rating) do
    base = rating - 5

    case pos do
      "DF" ->
        %{
          pac: clamp(base - 5, 50, 99),
          sho: clamp(base - 30, 30, 99),
          pas: clamp(base - 10, 50, 99),
          dri: clamp(base - 10, 50, 99),
          def: clamp(base + 8, 60, 99),
          phy: clamp(base + 8, 60, 99)
        }

      "MF" ->
        %{
          pac: clamp(base - 5, 50, 99),
          sho: clamp(base - 10, 50, 99),
          pas: clamp(base + 8, 60, 99),
          dri: clamp(base + 6, 60, 99),
          def: clamp(base - 10, 40, 99),
          phy: clamp(base - 5, 50, 99)
        }

      "FW" ->
        %{
          pac: clamp(base + 8, 60, 99),
          sho: clamp(base + 10, 60, 99),
          pas: clamp(base - 10, 40, 99),
          dri: clamp(base + 6, 60, 99),
          def: clamp(base - 40, 20, 99),
          phy: clamp(base, 50, 99)
        }
    end
  end

  defp gen_gk_stats(rating) do
    base = rating - 3

    %{
      div: clamp(base, 50, 99),
      han: clamp(base, 50, 99),
      kic: clamp(base - 5, 45, 99),
      ref: clamp(base + 4, 55, 99),
      spd: clamp(base - 20, 30, 99),
      pos: clamp(base, 50, 99)
    }
  end

  defp clamp(val, min, max) do
    cond do
      val < min -> min
      val > max -> max
      true -> val
    end
  end
end

Seeds.run()
