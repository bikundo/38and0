# Task Plan: Invincibles Premier League Retro Draft Game

## Goal
Implement a fast-paced Premier League retro draft game where the player drafts an 11-man squad under randomized Club/Era constraints and simulates a 38-game season in Phoenix LiveView, striving for a perfect 38-0-0 season.

## Current Phase
Delivery

## Phases

### Phase 1: Setup & Project Initialization
- [x] Initialize Phoenix 1.7+ project with LiveView, Tailwind CSS, and without unnecessary features (like mailer, dashboard, etc. to keep it clean)
- [x] Configure database connection to PostgreSQL
- **Status:** complete

### Phase 2: Schema and Database Setup
- [x] Create Ecto Migrations for `Club`, `Player`, and `Appearance`
- [x] Define the schemas in Ecto, specifying relations, indexes, and constraints (incorporating Supabase Postgres best practices)
- [x] Create a seed script (`priv/repo/seeds.exs`) containing historical Premier League clubs, players, and appearances (spanning 90s, 00s, 10s, 20s) to populate the database
- **Status:** complete

### Phase 3: Core Game Logic (SimEngine)
- [x] Create the `SimEngine` module with squad aggregates calculation
- [x] Implement match simulation logic with 5 possession checks per game, Gaussian random variance (`:rand.normal/0`), and early termination on non-wins
- [x] Write unit tests for `SimEngine` to verify mathematical stability and correctness
- **Status:** complete

### Phase 4: UI Development (Player Card & LiveView)
- [x] Implement the `player_card/1` core UI functional component with OVR-based gradients and the 3x2 attribute grid
- [x] Create the LiveView interface managing state (budget, lineup, spin, draft pool, record, step)
- [x] Build interactive game screens: Start screen, Wheel Spin / Drafting screen, Match Simulator progress view, Game Over / Winner's Hall of Fame
- [x] Refactored to turn off budget constraints and dynamically filter spin selections to empty lineup positions
- **Status:** complete

### Phase 5: Verification & Polish
- [x] Verify database constraints and index optimization
- [x] Manually test draft and simulation flows
- [x] Polish UI styling, colors, micro-animations, and responsive layouts
- **Status:** complete

## Key Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use composite index on `appearances(club_id, era)` | Speeds up the query which selects random appearances for the draft wheel. |
| Disable budget constraints | Shifted focus to a pure drafting strategy purely restricted by constraints and positions. |
| Filter spin pool by empty slots | Dynamically queries DB for only players matching the remaining empty slots, avoiding drafting dead ends. |
| Pure Elixir SimEngine | Ensures lightning-fast synchronous simulation of the 38-game season. |
