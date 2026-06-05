# Spin-by-Year Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the Premier League Retro Draft Game to spin a specific club and year/season, display all players from that team in the draft pool, grey out players who are already drafted (duplicate check) or have no compatible empty position slots, and allow selecting them into their eligible slots.

**Architecture:**
1. Update `Game.spin_wheel/0` to query a random appearance from the database, determine its `{club, season}`, and fetch **all** appearances matching that `{club, season}`.
2. In `GameLive` LiveView:
   - Modify `current_spin` to store `{club, season}` instead of `{club, era}`.
   - Implement duplicate player check: check if `appearance.player_id` is already in the lineup.
   - Implement position compatibility check: check if the player's position has any empty slots left in the lineup.
   - Disable drafting and grey out cards that fail the checks.
3. Update templates and testing to match.

**Tech Stack:** Elixir, Phoenix LiveView 1.0, Tailwind CSS, Ecto, PostgreSQL.

---

### Task 1: Update Game Context Functions

**Files:**
- Modify: `lib/invincibles/game.ex`
- Test: `test/invincibles/sim_engine_test.exs` (or add context tests)

- [ ] **Step 1: Update spin_wheel/0 to query by Season instead of Era**
  Update `lib/invincibles/game.ex` to implement `spin_wheel/0` selecting a random appearance to get a `{club, season}`, and then querying all appearances for that `{club, season}`.
  
  Code to implement in `lib/invincibles/game.ex`:
  ```elixir
  def spin_wheel do
    # 1. Fetch a random appearance from the DB to get a valid club + season/year
    random_app =
      from(a in Appearance,
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

        # 2. Fetch ALL appearances for that club and season
        appearances =
          from(a in Appearance,
            where: a.club_id == ^club.id and a.season == ^season,
            order_by: a.ovr,
            preload: [:player, :club]
          )
          |> Repo.all()

        {:ok, club, season, appearances}
    end
  end
  ```

- [ ] **Step 2: Run test to check compilation**
  Run: `mix compile`
  Expected: PASS

---

### Task 2: Refactor GameLive State and Handlers

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`

- [ ] **Step 3: Modify start_game and spin_wheel handlers to handle {club, season}**
  Update `lib/invincibles_web/live/game_live.ex` handlers.
  
  Let's replace:
  - `Game.spin_wheel(eligible)` calls to `Game.spin_wheel()` since we now return all players for a season and do the grey-out/disable rendering in the UI instead of database filtering.
  - In `handle_event("start_game", ...)` and `handle_event("spin_wheel", ...)`, change assigns to store `{club, season}` instead of `{club, era}`.
  
  Code to implement:
  ```elixir
  @impl true
  def handle_event("start_game", _params, socket) do
    socket = reset_state(socket)

    case Game.spin_wheel() do
      {:ok, club, season, appearances} ->
        socket =
          socket
          |> assign(:current_spin, {club, season})
          |> assign(:draft_pool, appearances)
          |> assign(:step, :drafting)
          |> clear_flash()

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load database players. Make sure the database is seeded.")}
    end
  end

  @impl true
  def handle_event("spin_wheel", _params, socket) do
    case Game.spin_wheel() do
      {:ok, club, season, appearances} ->
        socket =
          socket
          |> assign(:current_spin, {club, season})
          |> assign(:draft_pool, appearances)
          |> assign(:step, :drafting)
          |> clear_flash()

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load database players. Make sure the database is seeded.")}
    end
  end
  ```

- [ ] **Step 4: Implement duplicate player check and position checker helper**
  Add helper functions to check:
  - `player_already_drafted?(lineup, player_id)`: returns true if any slot in the lineup contains an appearance with this player's id.
  
  Code to add:
  ```elixir
  # Helper to check if a player is already drafted in the lineup
  defp player_already_drafted?(lineup, player_id) do
    Enum.any?(lineup, fn {_, app} ->
      not is_nil(app) and app.player_id == player_id
    end)
  end
  ```

---

### Task 3: Refactor UI Rendering and Card Component

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex` (render function)
- Modify: `lib/invincibles_web/components/player_card.ex`

- [ ] **Step 5: Update template render in game_live.ex to show greyed out and unselectable states**
  We will update the draft pool rendering block.
  - Calculate constraints description (e.g. Manchester United 2007-2008).
  - Loop through `@draft_pool`.
  - For each appearance:
    - Check if already drafted: `already_drafted = player_already_drafted?(@lineup, app.player_id)`
    - Check compatible slots: `slots = compatible_empty_slots(@lineup, app.player.primary_position)`
    - Check if unselectable: `unselectable = already_drafted or Enum.empty?(slots)`
    - If `already_drafted`, show "Already Drafted".
    - If `Enum.empty?(slots)` but not drafted, show "No Empty slots".
    - Pass a new `disabled` attribute to the player card or render it with opacity classes.
  
  Let's check the code block to modify in `game_live.ex`:
  ```elixir
  <div class="flex flex-col gap-4 max-h-[420px] overflow-y-auto pr-1">
    <%= for app <- @draft_pool do %>
      <% already_drafted = player_already_drafted?(@lineup, app.player_id) %>
      <% compatible_slots = compatible_empty_slots(@lineup, app.player.primary_position) %>
      <% unselectable = already_drafted or Enum.empty?(compatible_slots) %>
      
      <div class={[
        "bg-slate-950/40 border border-slate-800/60 rounded-2xl p-3 flex gap-3 transition-all",
        unselectable && "opacity-40 grayscale pointer-events-none"
      ]}>
        <!-- Tiny Player Card Preview -->
        <div class="flex-shrink-0">
          <.player_card appearance={app} class="!w-24 !h-36 !p-2 !rounded-lg" />
        </div>
        
        <!-- Draft Actions & Slot Matching -->
        <div class="flex-1 flex flex-col justify-between py-0.5">
          <div>
            <h4 class="font-black text-sm text-slate-100 truncate"><%= app.player.display_name %></h4>
            <p class="text-[10px] text-slate-500 font-medium mt-0.5"><%= app.player.primary_position %> | OVR <%= app.ovr %></p>
          </div>

          <div class="flex flex-wrap gap-1.5 mt-2">
            <%= cond do %>
              <% already_drafted -> %>
                <span class="text-[9px] font-bold text-amber-400 bg-amber-500/10 px-2 py-1 rounded-md uppercase">
                  Already Drafted
                </span>
              <% Enum.empty?(compatible_slots) -> %>
                <span class="text-[9px] font-bold text-slate-500 bg-slate-800 px-2 py-1 rounded-md uppercase">
                  No Empty Slots
                </span>
              <% true -> %>
                <%= for slot <- compatible_slots do %>
                  <button
                    phx-click="draft_player"
                    phx-value-appearance-id={app.id}
                    phx-value-position-key={slot}
                    class="bg-indigo-600 hover:bg-indigo-700 active:scale-95 text-white font-extrabold text-[9px] px-2 py-1 rounded shadow-sm tracking-wider uppercase transition-all"
                  >
                    As <%= @position_names[slot] %>
                  </button>
                <% end %>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
  </div>
  ```

- [ ] **Step 6: Update current constraint layout in HEEX template**
  Change the display label from `@current_spin` to show `club.name` and `season` year.

---

### Task 4: Run Verification Tests

**Files:**
- Modify: `test/invincibles_web/controllers/page_controller_test.exs`

- [ ] **Step 7: Run mix test**
  Run: `mix test`
  Expected: PASS

- [ ] **Step 8: Perform manual check by visiting the server**
  Verify the year is shown, pool is full of that year's squad, and duplicate players/no-empty-position cards are disabled and greyed out.
