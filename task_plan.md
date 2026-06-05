# Task Plan: Invincibles Premier League Retro Draft Game

## Goal
Implement a fast-paced Premier League retro draft game where the player drafts an 11-man squad under randomized Club/Era constraints and simulates a 38-game season in Phoenix LiveView, striving for a perfect 38-0-0 season.

## Current Phase
Phase 1

## Phases

### Phase 1: Setup & Project Initialization
- [ ] Initialize Phoenix 1.7+ project with LiveView, Tailwind CSS, and without unnecessary features (like mailer, dashboard, etc. to keep it clean)
- [ ] Configure database connection to PostgreSQL
- **Status:** in_progress

### Phase 2: Schema and Database Setup
- [ ] Create Ecto Migrations for `Club`, `Player`, and `Appearance`
- [ ] Define the schemas in Ecto, specifying relations, indexes, and constraints (incorporating Supabase Postgres best practices)
- [ ] Create a seed script (`priv/repo/seeds.exs`) containing historical Premier League clubs, players, and appearances (spanning 90s, 00s, 10s, 20s) to populate the database
- **Status:** pending

### Phase 3: Core Game Logic (SimEngine)
- [ ] Create the `SimEngine` module with squad aggregates calculation
- [ ] Implement match simulation logic with 5 possession checks per game, Gaussian random variance (`:rand.normal/0`), and early termination on non-wins
- [ ] Write unit tests for `SimEngine` to verify mathematical stability and correctness
- **Status:** pending

### Phase 4: UI Development (Player Card & LiveView)
- [ ] Implement the `player_card/1` core UI functional component with OVR-based gradients and the 3x2 attribute grid
- [ ] Create the LiveView interface managing state (budget, lineup, spin, draft pool, record, step)
- [ ] Build interactive game screens: Start screen, Wheel Spin / Drafting screen, Match Simulator progress view, Game Over / Winner's Hall of Fame
- **Status:** pending

### Phase 5: Verification & Polish
- [ ] Verify database constraints and index optimization
- [ ] Manually test draft and simulation flows
- [ ] Polish UI styling, colors, micro-animations, and responsive layouts
- **Status:** pending

## Key Questions
1. **What is the exact price formula for player cards based on OVR?**
   - Rationale: Draft budget starts at 200,000,000. Higher OVR players should cost more. We can scale it exponentially (e.g., 90+ cost 30M-80M, 83-89 cost 15M-30M, <83 cost 5M-15M) to make budgeting challenging.
2. **What are the player stats details?**
   - Outfielders: PAC, SHO, PAS, DRI, DEF, PHY.
   - Goalkeepers: DIV, HAN, KIC, REF, SPD, POS.

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use composite index on `appearances(club_id, era)` | Speeds up the query which selects random appearances for the draft wheel. |
| Exponential cost scaling for player draft values | Encourages budget strategy (balancing high-rated stars with budget enablers). |
| Pure Elixir SimEngine | Ensures lightning-fast synchronous simulation of the 38-game season. |
