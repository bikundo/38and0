alias Invincibles.Repo
alias Invincibles.Game.Club
alias Invincibles.Game.Player
alias Invincibles.Game.Appearance

# Insert Clubs
clubs_data = [
  %{name: "Arsenal", short_name: "ARS", primary_color: "#EF4444"},
  %{name: "Manchester United", short_name: "MUN", primary_color: "#DC2626"},
  %{name: "Chelsea", short_name: "CHE", primary_color: "#2563EB"},
  %{name: "Liverpool", short_name: "LIV", primary_color: "#B91C1C"},
  %{name: "Manchester City", short_name: "MCI", primary_color: "#0EA5E9"},
  %{name: "Blackburn Rovers", short_name: "BLB", primary_color: "#3B82F6"},
  %{name: "Tottenham Hotspur", short_name: "TOT", primary_color: "#1E293B"},
  %{name: "Newcastle United", short_name: "NEW", primary_color: "#0F172A"}
]

clubs =
  Enum.into(clubs_data, %{}, fn data ->
    club = Repo.insert!(Club.changeset(%Club{}, data))
    {data.name, club}
  end)

# Insert Players & Appearances Helper
insert_player_with_appearances = fn player_data, appearances_list ->
  player = Repo.insert!(Player.changeset(%Player{}, player_data))

  for app_data <- appearances_list do
    club = Map.fetch!(clubs, app_data.club_name)

    %Appearance{}
    |> Appearance.changeset(Map.merge(app_data, %{player_id: player.id, club_id: club.id}))
    |> Repo.insert!()
  end
end

# Seed Players
players_with_apps = [
  # --- GOALKEEPERS ---
  {
    %{name: "Peter Schmeichel", display_name: "P. Schmeichel", primary_position: "GK"},
    [
      %{club_name: "Manchester United", season: "1998-1999", era: "90s", ovr: 92, stats: %{div: 91, han: 89, kic: 85, ref: 93, spd: 60, pos: 92}}
    ]
  },
  {
    %{name: "David Seaman", display_name: "D. Seaman", primary_position: "GK"},
    [
      %{club_name: "Arsenal", season: "1997-1998", era: "90s", ovr: 87, stats: %{div: 86, han: 88, kic: 80, ref: 85, spd: 48, pos: 88}}
    ]
  },
  {
    %{name: "Petr Cech", display_name: "P. Cech", primary_position: "GK"},
    [
      %{club_name: "Chelsea", season: "2004-2005", era: "00s", ovr: 91, stats: %{div: 89, han: 92, kic: 78, ref: 91, spd: 55, pos: 90}}
    ]
  },
  {
    %{name: "Alisson Becker", display_name: "Alisson", primary_position: "GK"},
    [
      %{club_name: "Liverpool", season: "2019-2020", era: "10s", ovr: 89, stats: %{div: 86, han: 88, kic: 85, ref: 89, spd: 47, pos: 90}},
      %{club_name: "Liverpool", season: "2023-2024", era: "20s", ovr: 89, stats: %{div: 86, han: 89, kic: 85, ref: 90, spd: 47, pos: 90}}
    ]
  },
  {
    %{name: "Ederson Moraes", display_name: "Ederson", primary_position: "GK"},
    [
      %{club_name: "Manchester City", season: "2020-2021", era: "20s", ovr: 87, stats: %{div: 86, han: 82, kic: 93, ref: 87, spd: 64, pos: 86}}
    ]
  },
  {
    %{name: "Hugo Lloris", display_name: "H. Lloris", primary_position: "GK"},
    [
      %{club_name: "Tottenham Hotspur", season: "2016-2017", era: "10s", ovr: 87, stats: %{div: 88, han: 84, kic: 68, ref: 90, spd: 61, pos: 83}}
    ]
  },
  {
    %{name: "Tim Flowers", display_name: "T. Flowers", primary_position: "GK"},
    [
      %{club_name: "Blackburn Rovers", season: "1994-1995", era: "90s", ovr: 84, stats: %{div: 83, han: 84, kic: 72, ref: 85, spd: 45, pos: 83}}
    ]
  },
  {
    %{name: "Shay Given", display_name: "S. Given", primary_position: "GK"},
    [
      %{club_name: "Newcastle United", season: "2002-2003", era: "00s", ovr: 86, stats: %{div: 87, han: 82, kic: 75, ref: 89, spd: 50, pos: 84}}
    ]
  },

  # --- DEFENDERS ---
  {
    %{name: "Tony Adams", display_name: "T. Adams", primary_position: "DF"},
    [
      %{club_name: "Arsenal", season: "1997-1998", era: "90s", ovr: 88, stats: %{pac: 68, sho: 45, pas: 65, dri: 60, def: 90, phy: 88}}
    ]
  },
  {
    %{name: "William Saliba", display_name: "W. Saliba", primary_position: "DF"},
    [
      %{club_name: "Arsenal", season: "2023-2024", era: "20s", ovr: 89, stats: %{pac: 83, sho: 40, pas: 72, dri: 78, def: 89, phy: 84}}
    ]
  },
  {
    %{name: "Gary Neville", display_name: "G. Neville", primary_position: "DF"},
    [
      %{club_name: "Manchester United", season: "1998-1999", era: "90s", ovr: 85, stats: %{pac: 76, sho: 42, pas: 78, dri: 72, def: 85, phy: 82}},
      %{club_name: "Manchester United", season: "2002-2003", era: "00s", ovr: 85, stats: %{pac: 73, sho: 42, pas: 78, dri: 72, def: 86, phy: 80}}
    ]
  },
  {
    %{name: "Rio Ferdinand", display_name: "R. Ferdinand", primary_position: "DF"},
    [
      %{club_name: "Manchester United", season: "2007-2008", era: "00s", ovr: 90, stats: %{pac: 81, sho: 48, pas: 75, dri: 77, def: 91, phy: 86}}
    ]
  },
  {
    %{name: "John Terry", display_name: "J. Terry", primary_position: "DF"},
    [
      %{club_name: "Chelsea", season: "2004-2005", era: "00s", ovr: 90, stats: %{pac: 66, sho: 55, pas: 68, dri: 62, def: 92, phy: 89}}
    ]
  },
  {
    %{name: "Jamie Carragher", display_name: "J. Carragher", primary_position: "DF"},
    [
      %{club_name: "Liverpool", season: "2004-2005", era: "00s", ovr: 85, stats: %{pac: 68, sho: 35, pas: 64, dri: 59, def: 87, phy: 84}}
    ]
  },
  {
    %{name: "Virgil van Dijk", display_name: "van Dijk", primary_position: "DF"},
    [
      %{club_name: "Liverpool", season: "2019-2020", era: "10s", ovr: 91, stats: %{pac: 78, sho: 60, pas: 71, dri: 72, def: 92, phy: 89}},
      %{club_name: "Liverpool", season: "2021-2022", era: "20s", ovr: 91, stats: %{pac: 78, sho: 60, pas: 71, dri: 72, def: 92, phy: 89}}
    ]
  },
  {
    %{name: "Trent Alexander-Arnold", display_name: "Alexander-Arnold", primary_position: "DF"},
    [
      %{club_name: "Liverpool", season: "2021-2022", era: "20s", ovr: 86, stats: %{pac: 76, sho: 69, pas: 89, dri: 80, def: 80, phy: 73}}
    ]
  },
  {
    %{name: "Vincent Kompany", display_name: "V. Kompany", primary_position: "DF"},
    [
      %{club_name: "Manchester City", season: "2011-2012", era: "10s", ovr: 89, stats: %{pac: 73, sho: 50, pas: 68, dri: 68, def: 90, phy: 88}}
    ]
  },
  {
    %{name: "Ruben Dias", display_name: "R. Dias", primary_position: "DF"},
    [
      %{club_name: "Manchester City", season: "2022-2023", era: "20s", ovr: 89, stats: %{pac: 62, sho: 39, pas: 66, dri: 69, def: 90, phy: 87}}
    ]
  },
  {
    %{name: "Kieran Trippier", display_name: "K. Trippier", primary_position: "DF"},
    [
      %{club_name: "Newcastle United", season: "2022-2023", era: "20s", ovr: 84, stats: %{pac: 70, sho: 64, pas: 82, dri: 78, def: 81, phy: 72}}
    ]
  },
  {
    %{name: "Colin Hendry", display_name: "C. Hendry", primary_position: "DF"},
    [
      %{club_name: "Blackburn Rovers", season: "1994-1995", era: "90s", ovr: 84, stats: %{pac: 64, sho: 40, pas: 58, dri: 54, def: 86, phy: 88}}
    ]
  },
  {
    %{name: "Ledley King", display_name: "L. King", primary_position: "DF"},
    [
      %{club_name: "Tottenham Hotspur", season: "2005-2006", era: "00s", ovr: 86, stats: %{pac: 79, sho: 45, pas: 67, dri: 71, def: 88, phy: 83}}
    ]
  },

  # --- MIDFIELDERS ---
  {
    %{name: "Patrick Vieira", display_name: "P. Vieira", primary_position: "MF"},
    [
      %{club_name: "Arsenal", season: "2003-2004", era: "00s", ovr: 91, stats: %{pac: 83, sho: 74, pas: 83, dri: 85, def: 90, phy: 91}}
    ]
  },
  {
    %{name: "Martin Ødegaard", display_name: "Ødegaard", primary_position: "MF"},
    [
      %{club_name: "Arsenal", season: "2023-2024", era: "20s", ovr: 89, stats: %{pac: 78, sho: 81, pas: 89, dri: 88, def: 58, phy: 64}}
    ]
  },
  {
    %{name: "Roy Keane", display_name: "R. Keane", primary_position: "MF"},
    [
      %{club_name: "Manchester United", season: "1998-1999", era: "90s", ovr: 90, stats: %{pac: 75, sho: 72, pas: 83, dri: 79, def: 88, phy: 91}},
      %{club_name: "Manchester United", season: "2002-2003", era: "00s", ovr: 90, stats: %{pac: 70, sho: 72, pas: 84, dri: 78, def: 87, phy: 89}}
    ]
  },
  {
    %{name: "Paul Scholes", display_name: "P. Scholes", primary_position: "MF"},
    [
      %{club_name: "Manchester United", season: "1998-1999", era: "90s", ovr: 90, stats: %{pac: 72, sho: 86, pas: 90, dri: 84, def: 65, phy: 78}},
      %{club_name: "Manchester United", season: "2002-2003", era: "00s", ovr: 90, stats: %{pac: 68, sho: 86, pas: 91, dri: 84, def: 65, phy: 75}}
    ]
  },
  {
    %{name: "David Beckham", display_name: "D. Beckham", primary_position: "MF"},
    [
      %{club_name: "Manchester United", season: "1998-1999", era: "90s", ovr: 89, stats: %{pac: 76, sho: 83, pas: 92, dri: 82, def: 70, phy: 79}}
    ]
  },
  {
    %{name: "Ryan Giggs", display_name: "R. Giggs", primary_position: "MF"},
    [
      %{club_name: "Manchester United", season: "1998-1999", era: "90s", ovr: 89, stats: %{pac: 91, sho: 78, pas: 85, dri: 90, def: 48, phy: 68}},
      %{club_name: "Manchester United", season: "2002-2003", era: "00s", ovr: 89, stats: %{pac: 86, sho: 78, pas: 85, dri: 88, def: 48, phy: 66}}
    ]
  },
  {
    %{name: "Bruno Fernandes", display_name: "B. Fernandes", primary_position: "MF"},
    [
      %{club_name: "Manchester United", season: "2020-2021", era: "20s", ovr: 88, stats: %{pac: 75, sho: 86, pas: 89, dri: 84, def: 68, phy: 77}}
    ]
  },
  {
    %{name: "Frank Lampard", display_name: "F. Lampard", primary_position: "MF"},
    [
      %{club_name: "Chelsea", season: "2004-2005", era: "00s", ovr: 90, stats: %{pac: 74, sho: 88, pas: 89, dri: 82, def: 72, phy: 80}},
      %{club_name: "Chelsea", season: "2011-2012", era: "10s", ovr: 89, stats: %{pac: 68, sho: 88, pas: 89, dri: 80, def: 70, phy: 76}}
    ]
  },
  {
    %{name: "N'Golo Kante", display_name: "N. Kante", primary_position: "MF"},
    [
      %{club_name: "Chelsea", season: "2016-2017", era: "10s", ovr: 90, stats: %{pac: 80, sho: 66, pas: 78, dri: 82, def: 90, phy: 86}}
    ]
  },
  {
    %{name: "Cole Palmer", display_name: "C. Palmer", primary_position: "MF"},
    [
      %{club_name: "Chelsea", season: "2023-2024", era: "20s", ovr: 86, stats: %{pac: 80, sho: 85, pas: 86, dri: 87, def: 52, phy: 64}}
    ]
  },
  {
    %{name: "Steven Gerrard", display_name: "S. Gerrard", primary_position: "MF"},
    [
      %{club_name: "Liverpool", season: "2004-2005", era: "00s", ovr: 90, stats: %{pac: 81, sho: 87, pas: 88, dri: 84, def: 78, phy: 83}}
    ]
  },
  {
    %{name: "David Silva", display_name: "D. Silva", primary_position: "MF"},
    [
      %{club_name: "Manchester City", season: "2011-2012", era: "10s", ovr: 89, stats: %{pac: 72, sho: 74, pas: 89, dri: 89, def: 52, phy: 57}}
    ]
  },
  {
    %{name: "Yaya Toure", display_name: "Y. Toure", primary_position: "MF"},
    [
      %{club_name: "Manchester City", season: "2013-2014", era: "10s", ovr: 90, stats: %{pac: 78, sho: 86, pas: 86, dri: 84, def: 80, phy: 90}}
    ]
  },
  {
    %{name: "Kevin De Bruyne", display_name: "De Bruyne", primary_position: "MF"},
    [
      %{club_name: "Manchester City", season: "2019-2020", era: "10s", ovr: 93, stats: %{pac: 76, sho: 86, pas: 93, dri: 88, def: 62, phy: 78}},
      %{club_name: "Manchester City", season: "2021-2022", era: "20s", ovr: 93, stats: %{pac: 76, sho: 86, pas: 93, dri: 88, def: 62, phy: 78}}
    ]
  },
  {
    %{name: "Bruno Guimaraes", display_name: "B. Guimaraes", primary_position: "MF"},
    [
      %{club_name: "Newcastle United", season: "2023-2024", era: "20s", ovr: 86, stats: %{pac: 70, sho: 78, pas: 84, dri: 84, def: 80, phy: 82}}
    ]
  },
  {
    %{name: "Tim Sherwood", display_name: "T. Sherwood", primary_position: "MF"},
    [
      %{club_name: "Blackburn Rovers", season: "1994-1995", era: "90s", ovr: 83, stats: %{pac: 70, sho: 74, pas: 80, dri: 76, def: 78, phy: 82}}
    ]
  },
  {
    %{name: "Gareth Bale", display_name: "G. Bale", primary_position: "MF"},
    [
      %{club_name: "Tottenham Hotspur", season: "2012-2013", era: "10s", ovr: 90, stats: %{pac: 93, sho: 87, pas: 84, dri: 88, def: 70, phy: 80}}
    ]
  },

  # --- FORWARDS ---
  {
    %{name: "Thierry Henry", display_name: "T. Henry", primary_position: "FW"},
    [
      %{club_name: "Arsenal", season: "2003-2004", era: "00s", ovr: 94, stats: %{pac: 96, sho: 91, pas: 83, dri: 92, def: 42, phy: 80}}
    ]
  },
  {
    %{name: "Bukayo Saka", display_name: "B. Saka", primary_position: "FW"},
    [
      %{club_name: "Arsenal", season: "2023-2024", era: "20s", ovr: 88, stats: %{pac: 86, sho: 82, pas: 83, dri: 89, def: 55, phy: 68}}
    ]
  },
  {
    %{name: "Cristiano Ronaldo", display_name: "C. Ronaldo", primary_position: "FW"},
    [
      %{club_name: "Manchester United", season: "2007-2008", era: "00s", ovr: 93, stats: %{pac: 92, sho: 93, pas: 82, dri: 93, def: 45, phy: 85}}
    ]
  },
  {
    %{name: "Wayne Rooney", display_name: "W. Rooney", primary_position: "FW"},
    [
      %{club_name: "Manchester United", season: "2009-2010", era: "00s", ovr: 91, stats: %{pac: 84, sho: 90, pas: 82, dri: 86, def: 58, phy: 88}},
      %{club_name: "Manchester United", season: "2011-2012", era: "10s", ovr: 90, stats: %{pac: 80, sho: 90, pas: 83, dri: 85, def: 58, phy: 86}}
    ]
  },
  {
    %{name: "Marcus Rashford", display_name: "M. Rashford", primary_position: "FW"},
    [
      %{club_name: "Manchester United", season: "2022-2023", era: "20s", ovr: 84, stats: %{pac: 90, sho: 84, pas: 78, dri: 85, def: 42, phy: 74}}
    ]
  },
  {
    %{name: "Didier Drogba", display_name: "D. Drogba", primary_position: "FW"},
    [
      %{club_name: "Chelsea", season: "2006-2007", era: "00s", ovr: 89, stats: %{pac: 83, sho: 89, pas: 75, dri: 80, def: 48, phy: 90}}
    ]
  },
  {
    %{name: "Eden Hazard", display_name: "E. Hazard", primary_position: "FW"},
    [
      %{club_name: "Chelsea", season: "2018-2019", era: "10s", ovr: 92, stats: %{pac: 91, sho: 83, pas: 86, dri: 94, def: 35, phy: 66}}
    ]
  },
  {
    %{name: "Robbie Fowler", display_name: "R. Fowler", primary_position: "FW"},
    [
      %{club_name: "Liverpool", season: "1995-1996", era: "90s", ovr: 87, stats: %{pac: 84, sho: 89, pas: 72, dri: 82, def: 38, phy: 74}}
    ]
  },
  {
    %{name: "Luis Suarez", display_name: "L. Suarez", primary_position: "FW"},
    [
      %{club_name: "Liverpool", season: "2013-2014", era: "10s", ovr: 92, stats: %{pac: 84, sho: 92, pas: 82, dri: 90, def: 55, phy: 82}}
    ]
  },
  {
    %{name: "Mohamed Salah", display_name: "M. Salah", primary_position: "FW"},
    [
      %{club_name: "Liverpool", season: "2017-2018", era: "10s", ovr: 91, stats: %{pac: 93, sho: 89, pas: 82, dri: 90, def: 45, phy: 75}},
      %{club_name: "Liverpool", season: "2021-2022", era: "20s", ovr: 90, stats: %{pac: 90, sho: 88, pas: 82, dri: 89, def: 45, phy: 75}}
    ]
  },
  {
    %{name: "Sergio Aguero", display_name: "S. Aguero", primary_position: "FW"},
    [
      %{club_name: "Manchester City", season: "2014-2015", era: "10s", ovr: 91, stats: %{pac: 88, sho: 90, pas: 77, dri: 89, def: 32, phy: 74}}
    ]
  },
  {
    %{name: "Erling Haaland", display_name: "E. Haaland", primary_position: "FW"},
    [
      %{club_name: "Manchester City", season: "2022-2023", era: "20s", ovr: 91, stats: %{pac: 89, sho: 93, pas: 66, dri: 80, def: 45, phy: 88}}
    ]
  },
  {
    %{name: "Alan Shearer", display_name: "A. Shearer", primary_position: "FW"},
    [
      %{club_name: "Blackburn Rovers", season: "1994-1995", era: "90s", ovr: 91, stats: %{pac: 82, sho: 93, pas: 74, dri: 80, def: 44, phy: 86}},
      %{club_name: "Newcastle United", season: "1996-1997", era: "90s", ovr: 92, stats: %{pac: 81, sho: 94, pas: 76, dri: 80, def: 44, phy: 88}},
      %{club_name: "Newcastle United", season: "2002-2003", era: "00s", ovr: 90, stats: %{pac: 75, sho: 92, pas: 76, dri: 78, def: 44, phy: 88}}
    ]
  },
  {
    %{name: "Les Ferdinand", display_name: "L. Ferdinand", primary_position: "FW"},
    [
      %{club_name: "Newcastle United", season: "1995-1996", era: "90s", ovr: 86, stats: %{pac: 82, sho: 86, pas: 70, dri: 78, def: 40, phy: 85}}
    ]
  },
  {
    %{name: "Chris Sutton", display_name: "C. Sutton", primary_position: "FW"},
    [
      %{club_name: "Blackburn Rovers", season: "1994-1995", era: "90s", ovr: 84, stats: %{pac: 75, sho: 83, pas: 72, dri: 76, def: 52, phy: 85}}
    ]
  },
  {
    %{name: "Teddy Sheringham", display_name: "T. Sheringham", primary_position: "FW"},
    [
      %{club_name: "Tottenham Hotspur", season: "1995-1996", era: "90s", ovr: 86, stats: %{pac: 70, sho: 86, pas: 80, dri: 80, def: 42, phy: 75}}
    ]
  },
  {
    %{name: "Harry Kane", display_name: "H. Kane", primary_position: "FW"},
    [
      %{club_name: "Tottenham Hotspur", season: "2017-2018", era: "10s", ovr: 91, stats: %{pac: 74, sho: 92, pas: 82, dri: 83, def: 47, phy: 83}},
      %{club_name: "Tottenham Hotspur", season: "2020-2021", era: "20s", ovr: 91, stats: %{pac: 70, sho: 93, pas: 84, dri: 83, def: 47, phy: 83}}
    ]
  },
  {
    %{name: "Son Heung-min", display_name: "Son", primary_position: "FW"},
    [
      %{club_name: "Tottenham Hotspur", season: "2021-2022", era: "20s", ovr: 88, stats: %{pac: 88, sho: 88, pas: 82, dri: 86, def: 42, phy: 70}},
      %{club_name: "Tottenham Hotspur", season: "2018-2019", era: "10s", ovr: 87, stats: %{pac: 88, sho: 86, pas: 80, dri: 86, def: 42, phy: 68}}
    ]
  }
]

# Run inserts
for {player_data, apps} <- players_with_apps do
  insert_player_with_appearances.(player_data, apps)
end

IO.puts("Successfully seeded database with Premier League Clubs, Players, and Appearances!")
