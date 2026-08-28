# Invincibles (38 & 0)

> **Premier League Retro Squad Drafting & 38-Game Season Simulator**

[![Elixir](https://img.shields.io/badge/Elixir-1.17+-4B275F?logo=elixir&logoColor=white)](https://elixir-lang.org/)
[![Phoenix Framework](https://img.shields.io/badge/Phoenix-1.8-FD4F00?logo=phoenixframework&logoColor=white)](https://www.phoenixframework.org/)
[![Phoenix LiveView](https://img.shields.io/badge/LiveView-1.0-FD4F00)](https://hexdocs.pm/phoenix_live_view)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind-v4-38B2AC?logo=tailwindcss&logoColor=white)](https://tailwindcss.com/)

**Invincibles** is a fast-paced football management and drafting web game. Players spin for historical Premier League clubs and eras (spanning from 1992 to the present day), draft legendary players into custom formations, and simulate a full 38-game league campaign striving for the ultimate achievement: an undefeated **38-0-0 Invincible season**.

---

## Features

- **Interactive Spin Wheel & Squad Drafting**: Spin the wheel to randomize clubs and seasons/eras (90s, 00s, 10s, 20s), and draft real players into customizable tactical formations (`4-3-3`, `4-2-3-1`, `3-5-2`, `5-3-2`).
- **Pure Elixir Simulation Engine (`SimEngine`)**: Computes custom squad aggregate ratings across Attack, Control, Defense, and Goalkeeping, simulating 38 realistic Premier League fixtures with deterministic variance and matchday recaps.
- **Mobile-First Pitch Visualizer**: Responsive soccer pitch board with tactile circular player badges, position descriptions, and smooth micro-animations.
- **Shareable Lineup Cards (`/share/:id`)**: Generate persistent, shareable campaign cards with complete match statistics, formation layouts, and witty manager commentary (Jose Mourinho masterclasses, Roy Hodgson relegation roasts, and more).
- **Global Manager Leaderboard**: Real-time leaderboard tracking all-time top scores, goal difference, win records, and total campaigns simulated worldwide.
- **Historical Retro Squads Directory (`/squads`)**: Comprehensive directory covering 30+ seasons (1992–2024), ~6,700 players, and ~23,000 appearances with preset links to start drafts directly from any historical squad sheet.
- **Search & AI Bot Optimization**: Rich JSON-LD structured schemas (`ItemList`, `SportsTeam`, `FAQPage`), dynamic Open Graph & Twitter Cards, and automated XML sitemap generation (`/sitemap.xml`).

---

## Tech Stack

- **Backend & Logic**: Elixir 1.17+, Phoenix Framework 1.8, Phoenix LiveView 1.0 (WebSocket-driven reactive UI with zero SPA client-bundle overhead).
- **HTTP Server**: [Bandit](https://github.com/mtrudel/bandit) (high-performance pure Elixir HTTP/WebSocket server).
- **Database & Data Layer**: PostgreSQL, Ecto with composite indexes for fast randomized query execution.
- **Frontend & Styling**: Tailwind CSS v4, custom fluid typography, CSS keyframe animations, and [topbar](https://buunguyen.github.io/topbar/) progress indicators.
- **Asset Pipeline**: Esbuild and Tailwind standalone CLI via Mix integration.

---

## Prerequisites

Ensure you have the following installed on your local machine:

- **Erlang/OTP**: 26+
- **Elixir**: 1.17+
- **PostgreSQL**: 14+ (running locally on default port `5432`)
- **Node.js** (Optional, only needed if modifying vendor packages)

---

## Local Development Setup

### 1. Clone the Repository

```bash
git clone <repo-url>
cd 38and0
```

### 2. Install Dependencies & Setup Database

Run the automated setup alias:

```bash
mix setup
```

This runs:
1. `mix deps.get` – Fetches Elixir dependencies.
2. `mix ecto.setup` – Creates the database, executes migrations, and seeds the historical players/clubs dataset from `DATA_JSON/`.
3. `mix assets.setup` – Configures Tailwind and Esbuild tools.
4. `mix assets.build` – Compiles JS and CSS bundles.

### 3. Start the Phoenix Server

Start the local development server:

```bash
mix phx.server
```

Or run interactively inside IEx:

```bash
iex -S mix phx.server
```

Now visit [`http://localhost:4000`](http://localhost:4000) in your browser.

---

## Database Management & Seeding

### Seeding from Source Data
The project includes a historical dataset containing 30+ seasons in `DATA_JSON/` and match statistics in `stats/`. To re-seed the database:

```bash
mix run priv/repo/seeds.exs
```

### Restoring from Database Dump (Fast Alternative)
A complete SQL dump is included in `priv/db_dump.sql`. You can restore it directly:

```bash
mix ecto.create
psql invincibles_dev < priv/db_dump.sql
```

### Resetting the Database
To drop, recreate, run migrations, and reseed:

```bash
mix ecto.reset
```

---

## Running Tests & Precommit Checks

Execute the automated test suite:

```bash
mix test
```

To run the full precommit pipeline (unused dependencies unlock, code formatting, warnings-as-errors compilation, and complete test suite):

```bash
mix precommit
```

---

## Project Structure

```
38and0/
├── assets/                    # Frontend assets (Tailwind CSS, JS hooks, Topbar)
├── config/                    # Environment configurations (dev, test, prod, runtime)
├── DATA_JSON/                 # Historical Premier League squad datasets (1992–2024)
├── deployment/                # Systemd service unit and Nginx configuration templates
├── docs/                      # Documentation, implementation plans, and design specs
│   ├── guides/                # VPS and deployment setup guides
│   ├── plans/                 # Architecture and feature implementation plans
│   └── specs/                 # Design specs and product requirements
├── lib/
│   ├── invincibles/           # Domain logic & core contexts
│   │   ├── game.ex            # Game context (drafting, queries, shares, leaderboard)
│   │   ├── game/              # Schemas (Club, Player, Appearance, Share) & SimEngine
│   │   ├── release.ex         # Release migration tasks for production
│   │   └── repo.ex            # Ecto PostgreSQL repository
│   └── invincibles_web/       # Web layer & user interface
│       ├── components/        # Functional UI components (PlayerCard, Layouts, CoreComponents)
│       ├── controllers/       # HTTP controllers (Sitemaps, Error handlers)
│       ├── live/              # Phoenix LiveViews (GameLive, DirectoryLive, ShareLive)
│       ├── endpoint.ex        # Phoenix Endpoint
│       └── router.ex          # Application routing table
├── priv/
│   ├── db_dump.sql            # Full PostgreSQL database backup dump
│   ├── repo/migrations/       # Ecto database migrations
│   ├── repo/seeds.exs         # Database seed script
│   └── static/                # Static assets (images, favicon, robots.txt)
├── stats/                     # Historical Premier League season statistics CSVs
└── test/                      # ExUnit test suites (contexts, controllers, LiveViews)
```

---

## Production Deployment

The project is configured for automated Continuous Deployment via **GitHub Actions** (`.github/workflows/deploy.yml`):

1. Builds assets and creates a production release via `mix release`.
2. Packages the release tarball and copies systemd/nginx configuration files to the target VPS via SSH/SCP.
3. Runs database migrations on release boot via `Invincibles.Release.migrate/0`.
4. Restarts the Systemd service (`invincibles.service`) and reloads Nginx.

For manual deployment instructions and VPS provisioning details, refer to [`docs/guides/vps_nginx_setup_guide.md`](docs/guides/vps_nginx_setup_guide.md).
