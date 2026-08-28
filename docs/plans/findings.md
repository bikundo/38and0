# Research & Discovery: Invincibles Premier League Retro Draft Game

This document outlines the research, discoveries, and design patterns for the "Invincibles: 38-0-0" Premier League Retro Draft Game.

## 1. Stack and Version Constraints
- **Elixir**: 1.17+ (we have 1.19.5, which is fully compatible)
- **Phoenix**: 1.7+ (we have installer 1.8.1, generating Phoenix 1.7+ apps)
- **Phoenix LiveView**: 1.0.0 (we will ensure the app uses `phoenix_live_view` ~> 1.0.0 in its `mix.exs`)
- **Tailwind CSS**: 3.4+
- **PostgreSQL**: 16+ / Ecto 3.11+

## 2. Ecto Schema & Migration Layout
To satisfy the requirements and the **Supabase Postgres Best Practices** (such as indexing foreign keys and composite indexes on filter fields), the schemas and indices are designed as:

- `clubs`:
  - `name` (string, e.g. "Manchester United")
  - `short_name` (string, max 4 chars, e.g. "MUN")
  - `primary_color` (string, hex code for UI theme)
  - *Indexes*: Unique index on `short_name` and `name`.

- `players`:
  - `name` (string)
  - `display_name` (string)
  - `primary_position` (string: "GK", "DF", "MF", "FW")
  - *Indexes*: Index on `primary_position`.

- `appearances`:
  - `player_id` (references `players`, on_delete: :delete_all)
  - `club_id` (references `clubs`, on_delete: :delete_all)
  - `season` (string, e.g., "2003-2004")
  - `era` (string, "90s", "00s", "10s", "20s")
  - `ovr` (integer, 50-99)
  - `stats` (map/jsonb, storing outpatient stats like `pac`, `sho`, `pas`, `dri`, `def`, `phy` OR keeper stats like `div`, `han`, `kic`, `ref`, `spd`, `pos`)
  - *Indexes*:
    - Foreign keys: `player_id`, `club_id` (critical for CASCADE and JOINs).
    - Composite index: `{club_id, era}` for fast randomized drafting queries.

## 3. Simulation Engine Algorithm
Pure Elixir module `SimEngine` to process a 38-game season synchronously:

1. **Squad Aggregates**:
   - `Attack Strength` = Sum of FW's `sho` + (MF's `pas` * 0.5)
   - `Control Strength` = Sum of MF's `dri`/`pas` + (DF's `pas` * 0.3)
   - `Defensive Strength` = Sum of DF's `def`/`phy` + (MF's `def` * 0.5)
   - `Goalkeeping Strength` = Average/Sum of GK's attributes: `div`, `han`, `kic`, `ref`, `spd`, `pos` (we'll define a clear aggregate formula, e.g. average or sum).

2. **Match Simulation (Repeat 38 times unless draw/loss)**:
   - Opponent Mid-Table Baseline: Average OVR = 80 across all lines (Attack: 80, Control: 80, Defense: 80, GK: 80).
   - Simulate 5 possession interactions per match:
     - **Control Check**: Midfield Control vs Opponent Control with random variance. Winner gets the attack vector.
     - **Shot Quality**: Attacker's Attack Strength vs Defender's Defensive Strength -> shot quality metric.
     - **Goalkeeper Check**: Shot vs Goalkeeper Strength using Gaussian variance (`:rand.normal/0`).
   - If User draws or loses a match, break early and return the current record.

## 4. UI Layer
- **Player Card Component (`player_card/1`)**: Render an FC-Style card with:
  - Dynamic gradient wrapper:
    - `ovr >= 90`: Gold/Amber Legend theme
    - `ovr` between 83 and 89: Rare Gold theme
    - `ovr < 83`: Common Silver/Slate theme
  - OVR & Position in top-left.
  - Club short name & Era in middle.
  - Bold uppercase player name.
  - 3x2 grid of stats at the bottom (outfield stats `PAC`, `SHO`, etc. vs GK stats `DIV`, `HAN`, etc.).
