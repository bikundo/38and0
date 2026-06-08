# SEO & Programmatic Directory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optimize application's metadata (Open Graph / Twitter Cards) for sharing, configure robots.txt for AI search bots, generate a dynamic XML sitemap, and build programmatic landing pages for historical football club squads (e.g. `/squads/:club_slug/:season_slug`) to capture retro squad search traffic.

**Architecture:**
- Create dynamic meta-tag handlers in `root.html.heex` using socket assigns.
- Build a dynamic `SitemapController` to automatically serve an XML sitemap of all clubs/seasons.
- Implement `DirectoryLive` LiveView to render static indexable squads page templates with metadata and structured schemas.
- Route requests and link everything together.

**Tech Stack:** Elixir, Phoenix LiveView 1.0, PostgreSQL, Nginx, Ecto.

---

### Task 1: Update Global Layout & Robots.txt

We will add dynamic tags to the root layout and update robots.txt to guide search crawlers.

**Files:**
- Modify: `lib/invincibles_web/components/layouts/root.html.heex`
- Modify: `priv/static/robots.txt`

- [ ] **Step 1: Update root.html.heex head tags**
  Open [root.html.heex](file:///Users/bix/Documents/code/Js/38and0/lib/invincibles_web/components/layouts/root.html.heex) and add dynamic meta descriptions, Open Graph, and Twitter Card tags.
  Ensure live_title suffix is updated to ` · Premier League Retro Draft`.
  
  Code to add inside `<head>`:
  ```heex
      <meta name="description" content={assigns[:meta_description] || "Draft legendary Premier League players, simulate a 38-game season, and build your own undefeated Invincibles squad."} />
      <meta property="og:title" content={assigns[:og_title] || assigns[:page_title] || "Invincibles - Premier League Retro Draft Game"} />
      <meta property="og:description" content={assigns[:og_description] || assigns[:meta_description] || "Draft legendary Premier League players, simulate a 38-game season, and build your own undefeated Invincibles squad."} />
      <meta property="og:type" content="website" />
      <meta property="og:url" content={"https://invincibles.website" <> (assigns[:current_path] || "")} />
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content={assigns[:og_title] || assigns[:page_title] || "Invincibles - Premier League Retro Draft Game"} />
      <meta name="twitter:description" content={assigns[:og_description] || assigns[:meta_description] || "Draft legendary Premier League players, simulate a 38-game season, and build your own undefeated Invincibles squad."} />
  ```

- [ ] **Step 2: Update robots.txt**
  Open [robots.txt](file:///Users/bix/Documents/code/Js/38and0/priv/static/robots.txt) and replace its content with the following:
  ```text
  User-agent: *
  Allow: /

  # Allow AI Search & Citation bots
  User-agent: GPTBot
  Allow: /
  User-agent: ChatGPT-User
  Allow: /
  User-agent: PerplexityBot
  Allow: /
  User-agent: ClaudeBot
  Allow: /

  # Block aggressive scrapers
  User-agent: CCBot
  Disallow: /

  Sitemap: https://invincibles.website/sitemap.xml
  ```

---

### Task 2: Update Existing LiveViews Metadata

Assign custom metadata to the socket during mount/handle_params in current routes.

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`
- Modify: `lib/invincibles_web/live/share_live.ex`

- [ ] **Step 3: Assign metadata in GameLive**
  Open `lib/invincibles_web/live/game_live.ex` and add the default metadata assigns:
  ```elixir
  socket =
    socket
    |> assign(:page_title, "Play Retro Premier League Draft Simulator")
    |> assign(:meta_description, "Draft legendary players from the 90s, 00s, 10s, or 20s. Build custom formations, simulate matches, and lead your squad to an undefeated 38-0-0 season.")
    |> assign(:current_path, "/")
  ```

- [ ] **Step 4: Assign dynamic metadata in ShareLive**
  Open `lib/invincibles_web/live/share_live.ex` and extract the share details inside `mount` to populate Open Graph titles and descriptions:
  ```elixir
  pts = share.season_record.wins * 3 + share.season_record.draws
  record_str = "#{share.season_record.wins}W - #{share.season_record.draws}D - #{share.season_record.losses}L"

  status =
    cond do
      share.season_record.wins == 38 -> "Perfect 38-0-0 Season!"
      share.season_record.losses == 0 -> "Undefeated Invincible Season!"
      true -> "Finished with #{pts} Points!"
    end

  og_title = "My Retro Lineup: #{status}"
  og_desc = "Check out my #{share.formation} draft squad for the #{share.season_label || "retro"} season. Record: #{record_str}. Quote: \"#{share.funny_quote}\""

  socket =
    socket
    |> assign(:page_title, "Shared Lineup - #{status}")
    |> assign(:og_title, og_title)
    |> assign(:og_description, og_desc)
    |> assign(:meta_description, og_desc)
    |> assign(:current_path, "/share/#{id}")
  ```

---

### Task 3: Implement Database Helpers for Programmatic Queries

Add support queries to retrieve seasons list and clean squad appearances.

**Files:**
- Modify: `lib/invincibles/game.ex`

- [ ] **Step 5: Add directory helper functions to Game context**
  Add these functions to [game.ex](file:///Users/bix/Documents/code/Js/38and0/lib/invincibles/game.ex):
  ```elixir
  def list_seasons_for_club(club_id) do
    from(a in Invincibles.Game.Appearance,
      where: a.club_id == ^club_id,
      select: a.season,
      distinct: true,
      order_by: [desc: a.season]
    )
    |> Repo.all()
  end

  def list_appearances_for_club_and_season(club_id, season) do
    from(a in Invincibles.Game.Appearance,
      where: a.club_id == ^club_id and a.season == ^season,
      order_by: [desc: a.ovr],
      preload: [:player, :club]
    )
    |> Repo.all()
  end

  def list_all_clubs do
    from(c in Invincibles.Game.Club, order_by: c.name)
    |> Repo.all()
  end
  ```

---

### Task 4: Create Programmatic SEO Directory LiveView

Build the landing pages at `/squads/:club_slug` and `/squads/:club_slug/:season_slug` containing complete squad ratings and draft CTAs.

**Files:**
- Create: `lib/invincibles_web/live/directory_live.ex`

- [ ] **Step 6: Write DirectoryLive controller and templates**
  Create `lib/invincibles_web/live/directory_live.ex` with structural logic and HEEx markup representing a starbucks/retro-styled squad page with tabular layout and play triggers. Include SEO ItemList schema.

---

### Task 5: Create Dynamic XML Sitemap

Automatically compile sitemap URLs of all clubs and seasons dynamically from Ecto.

**Files:**
- Create: `lib/invincibles_web/controllers/sitemap_controller.ex`
- Create: `lib/invincibles_web/controllers/sitemap_html.ex`
- Create: `lib/invincibles_web/controllers/sitemap_html/sitemap.xml.heex`

- [ ] **Step 7: Implement SitemapController and XML template**
  Write the controller, HTML wrapper module, and `.xml.heex` template file.

---

### Task 6: Configure Router & Navigation Link

Register the new dynamic directories and XML endpoints, and add a link to the bottom of the main layout so it's discoverable by spiders.

**Files:**
- Modify: `lib/invincibles_web/router.ex`
- Modify: `lib/invincibles_web/components/layouts/app.html.heex` (or layouts.ex)

- [ ] **Step 8: Register routes in router.ex**
  Add sitemap and live routes.
  
- [ ] **Step 9: Add a footer link to the layout**
  Add a footer link or similar path to internal directories.

---

### Task 7: Verification

**Files:**
- None (Command line checks)

- [ ] **Step 10: Run mix precommit**
  Ensure all tests pass and formatting compiles successfully.
