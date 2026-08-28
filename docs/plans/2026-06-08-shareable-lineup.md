# Shareable Lineup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to save their squad lineup and record details to the database and get a unique 48-hour share link that gracefully redirects to the homepage if expired or not found.

**Architecture:** Create a `shares` DB table with a UUID primary key, a background `ShareCleanupWorker` running as an OTP GenServer to periodically purge shares older than 48 hours, and a read-only `ShareLive` route `/share/:id`. The sharing action is integrated via Phoenix LiveView push events.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, PostgreSQL, Tailwind CSS.

---

### Task 1: Database Migration for Shares Table

**Files:**
- Create: `priv/repo/migrations/YYYYMMDDHHMMSS_create_shares.exs` (exact filename depends on timestamp when generated)
- Test: Run migration with `mix ecto.migrate`

- [ ] **Step 1: Create the migration file**
  Generate or manually write the migration file with a UUID primary key (`:binary_id`) and maps for `lineup` and `season_record`.

  *Content for `priv/repo/migrations/20260608144000_create_shares.exs`:*
  ```elixir
  defmodule Invincibles.Repo.Migrations.CreateShares do
    use Ecto.Migration

    def change do
      create table(:shares, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :formation, :string, null: false
        add :lineup, :map, null: false
        add :season_record, :map, null: false
        add :season_label, :string
        add :funny_quote, :text, null: false

        timestamps()
      end
    end
  end
  ```

- [ ] **Step 2: Run migration**
  Run: `mix ecto.migrate`
  Expected: Database migrated successfully.

- [ ] **Step 3: Commit**
  ```bash
  git add priv/repo/migrations/*_create_shares.exs
  git commit -m "db: create shares migration"
  ```

---

### Task 2: Shares Schema definition

**Files:**
- Create: `lib/invincibles/game/share.ex`
- Test: Check syntax with `mix compile`

- [ ] **Step 1: Write Ecto Schema for Share**
  Write the schema mapping attributes to database fields with a UUID primary key.

  *Content for `lib/invincibles/game/share.ex`:*
  ```elixir
  defmodule Invincibles.Game.Share do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id
    schema "shares" do
      field :formation, :string
      field :lineup, :map
      field :season_record, :map
      field :season_label, :string
      field :funny_quote, :string

      timestamps()
    end

    def changeset(share, attrs) do
      share
      |> cast(attrs, [:formation, :lineup, :season_record, :season_label, :funny_quote])
      |> validate_required([:formation, :lineup, :season_record, :funny_quote])
    end
  end
  ```

- [ ] **Step 2: Verify compilation**
  Run: `mix compile`
  Expected: Compiles without errors.

- [ ] **Step 3: Commit**
  ```bash
  git add lib/invincibles/game/share.ex
  git commit -m "feat: define Share schema"
  ```

---

### Task 3: Context Functions for Sharing

**Files:**
- Modify: `lib/invincibles/game.ex`
- Create: `test/invincibles/game_share_test.exs`

- [ ] **Step 1: Add share context functions**
  Implement `create_share/5` and `get_share/1` to retrieve the shares, check expiration, and reconstruct full lineups.

  *Content to append in `lib/invincibles/game.ex` (before final `end`):*
  ```elixir
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
  ```

- [ ] **Step 2: Write tests for sharing context**
  Write tests in a new file `test/invincibles/game_share_test.exs` to verify creation, retrieval, and expiration of share links.

  *Content for `test/invincibles/game_share_test.exs`:*
  ```elixir
  defmodule Invincibles.GameShareTest do
    use Invincibles.DataCase
    alias Invincibles.Game

    # Create helper mock player and club to draft
    setup do
      club = Repo.insert!(%Invincibles.Game.Club{name: "Test Share FC", short_name: "TSFC", primary_color: "#000"})
      player = Repo.insert!(%Invincibles.Game.Player{name: "John Share", display_name: "J. Share", primary_position: "FW"})
      appearance = Repo.insert!(%Invincibles.Game.Appearance{player: player, club: club, season: "2023-24", era: "Modern", ovr: 85, stats: %{}})
      
      {:ok, appearance: appearance}
    end

    test "create_share/5 saves and get_share/1 reconstructs lineup correctly", %{appearance: app} do
      lineup = %{st: app, gk: nil}
      record = %{wins: 30, draws: 8, losses: 0, gf: 90, ga: 15, week: 38}
      funny_quote = "A legendary run!"

      assert {:ok, share} = Game.create_share(lineup, "4-3-3", record, "2023-24", funny_quote)
      assert {:ok, retrieved} = Game.get_share(share.id)

      assert retrieved.formation == "4-3-3"
      assert retrieved.funny_quote == funny_quote
      assert retrieved.season_record.wins == 30
      assert retrieved.lineup[:st].id == app.id
    end

    test "get_share/1 deletes and rejects expired share" do
      # Insert share with manually backdated inserted_at
      backdated = NaiveDateTime.utc_now() |> NaiveDateTime.add(-172_900, :second) # > 48 hours
      
      {:ok, share} = 
        %Invincibles.Game.Share{}
        |> Invincibles.Game.Share.changeset(%{
          formation: "4-3-3",
          lineup: %{"gk" => nil},
          season_record: %{"wins" => 0, "draws" => 0, "losses" => 0, "gf" => 0, "ga" => 0},
          season_label: "2023-24",
          funny_quote: "Expired"
        })
        |> Repo.insert()

      # Overwrite inserted_at
      {1, _} = Repo.update_all(from(s in Invincibles.Game.Share, where: s.id == ^share.id), set: [inserted_at: backdated])

      assert Game.get_share(share.id) == :error
      # Check that it got deleted
      assert Repo.get(Invincibles.Game.Share, share.id) == nil
    end
  end
  ```

- [ ] **Step 3: Run the new test**
  Run: `mix test test/invincibles/game_share_test.exs`
  Expected: PASS

- [ ] **Step 4: Commit**
  ```bash
  git add lib/invincibles/game.ex test/invincibles/game_share_test.exs
  git commit -m "feat: implement share context functions and tests"
  ```

---

### Task 4: Background Cleanup Worker

**Files:**
- Create: `lib/invincibles/game/share_cleanup_worker.ex`
- Modify: `lib/invincibles/application.ex`
- Create: `test/invincibles/share_cleanup_worker_test.exs`

- [ ] **Step 1: Write the GenServer cleanup worker**
  Create a cleanup worker that executes `delete_all` for records older than 48 hours.

  *Content for `lib/invincibles/game/share_cleanup_worker.ex`:*
  ```elixir
  defmodule Invincibles.Game.ShareCleanupWorker do
    use GenServer
    import Ecto.Query
    alias Invincibles.Repo
    alias Invincibles.Game.Share
    require Logger

    # Check cleanup every 30 minutes
    @cleanup_interval :timer.minutes(30)

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl true
    def init(opts) do
      schedule_cleanup()
      {:ok, opts}
    end

    @impl true
    def handle_info(:cleanup, state) do
      # Calculate cutoff time (48 hours ago)
      cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-172_800, :second)

      # Delete all shares inserted before the cutoff
      query = from(s in Share, where: s.inserted_at < ^cutoff)
      {count, _} = Repo.delete_all(query)

      if count > 0 do
        Logger.info("[ShareCleanupWorker] Purged #{count} expired shares.")
      end

      schedule_cleanup()
      {:noreply, state}
    end

    defp schedule_cleanup do
      Process.send_after(self(), :cleanup, @cleanup_interval)
    end
  end
  ```

- [ ] **Step 2: Add Cleanup Worker to Supervision Tree**
  Add the worker to the list of children in `Invincibles.Application`.

  *Snippet to modify in `lib/invincibles/application.ex`:*
  ```elixir
      children = [
        InvinciblesWeb.Telemetry,
        Invincibles.Repo,
        {DNSCluster, query: Application.get_env(:invincibles, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Invincibles.PubSub},
        # Start share cleanup worker
        Invincibles.Game.ShareCleanupWorker,
        InvinciblesWeb.Endpoint
      ]
  ```

- [ ] **Step 3: Write test for cleanup worker**
  Write a test case to verify that the worker cleans up expired shares.

  *Content for `test/invincibles/share_cleanup_worker_test.exs`:*
  ```elixir
  defmodule Invincibles.Game.ShareCleanupWorkerTest do
    use Invincibles.DataCase
    alias Invincibles.Game.Share
    alias Invincibles.Game.ShareCleanupWorker

    test "cleanup deletes records older than 48 hours" do
      # Insert one active and one expired share
      {:ok, active} = 
        Repo.insert(%Share{
          formation: "4-3-3",
          lineup: %{},
          season_record: %{},
          funny_quote: "Active"
        })

      {:ok, expired} = 
        Repo.insert(%Share{
          formation: "4-3-3",
          lineup: %{},
          season_record: %{},
          funny_quote: "Expired"
        })

      # Backdate the expired record
      backdated = NaiveDateTime.utc_now() |> NaiveDateTime.add(-172_900, :second)
      {1, _} = Repo.update_all(from(s in Share, where: s.id == ^expired.id), set: [inserted_at: backdated])

      # Manually call handle_info on the cleanup worker
      {:noreply, _state} = ShareCleanupWorker.handle_info(:cleanup, %{})

      # Verify expired is gone, active remains
      assert Repo.get(Share, active.id) != nil
      assert Repo.get(Share, expired.id) == nil
    end
  end
  ```

- [ ] **Step 4: Run tests**
  Run: `mix test test/invincibles/share_cleanup_worker_test.exs`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/invincibles/game/share_cleanup_worker.ex lib/invincibles/application.ex test/invincibles/share_cleanup_worker_test.exs
  git commit -m "feat: implement share background cleanup worker and test"
  ```

---

### Task 5: Expose Formation Layouts and Create ShareLive LiveView

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`
- Create: `lib/invincibles_web/live/share_live.ex`

- [ ] **Step 1: Expose formation layouts in GameLive**
  Make formation layouts publicly accessible so `ShareLive` can render the pitch layout consistently.

  *Append to `lib/invincibles_web/live/game_live.ex` (before final `end`):*
  ```elixir
    def formation_layouts, do: @formation_layouts
  ```

- [ ] **Step 2: Create ShareLive LiveView**
  Implement `ShareLive` which fetches the share, handles missing/expired states by redirecting to `/` with a flash message, and renders the pitch and stats card in read-only mode.

  *Content for `lib/invincibles_web/live/share_live.ex`:*
  ```elixir
  defmodule InvinciblesWeb.ShareLive do
    use InvinciblesWeb, :live_view
    alias Invincibles.Game
    alias InvinciblesWeb.GameLive
    alias InvinciblesWeb.Layouts

    @impl true
    def mount(%{"id" => id}, _session, socket) do
      case Game.get_share(id) do
        {:ok, share} ->
          socket =
            socket
            |> assign(:share, share)
            |> assign(:lineup, share.lineup)
            |> assign(:formation, share.formation)
            |> assign(:season_record, share.season_record)
            |> assign(:season_label, share.season_label)
            |> assign(:funny_quote, share.funny_quote)
            |> assign(:formation_layouts, GameLive.formation_layouts())
            |> assign(:position_names, %{
              gk: "GK", lb: "LB", cb1: "CB", cb2: "CB", cb3: "CB", rb: "RB",
              lm: "LM", cm: "CM", cm1: "CM", cm2: "CM", cm3: "CM", rm: "RM",
              lw: "LW", rw: "RW", st: "ST", st1: "ST", st2: "ST"
            })
            |> assign(:position_descriptions, %{
              gk: "Goalkeeper", lb: "Left", cb1: "Centre", cb2: "Centre", cb3: "Centre", rb: "Right",
              lm: "Left", cm: "Attacking", cm1: "Defensive", cm2: "Defensive", cm3: "Centre", rm: "Right",
              lw: "Left", rw: "Right", st: "Striker", st1: "Striker", st2: "Striker"
            })

          {:ok, socket}

        _ ->
          socket =
            socket
            |> put_flash(:error, "Shared lineup not found or has expired.")
            |> redirect(to: "/")

          {:ok, socket}
      end
    end

    @impl true
    def render(assigns) do
      ~H"""
      <Layouts.app flash={@flash} record={@season_record}>
        <div class="min-h-screen bg-[#f2f0eb] text-[rgba(0,0,0,0.87)] font-sans flex flex-col pb-12">
          <!-- Main container -->
          <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-6 flex-1 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start w-full">
            <!-- Left 8 columns: Game Board & Lineup Pitch -->
            <div class="order-2 lg:order-1 lg:col-span-8 flex flex-col gap-6">
              <div class="bg-[#f2f0eb] flex flex-col gap-4">
                <!-- Soccer Pitch Lineup View -->
                <div class="relative bg-[#006241] border-4 border-[#1E3932] rounded-3xl p-6 overflow-hidden min-h-[660px] flex flex-col justify-between shadow-lg select-none">
                  <!-- Soccer Pitch Lines -->
                  <div class="absolute inset-4 border border-white/20 rounded-2xl pointer-events-none"></div>
                  <div class="absolute inset-x-4 top-1/2 h-px bg-white/20 -translate-y-1/2 pointer-events-none"></div>
                  <div class="absolute top-1/2 left-1/2 w-36 h-36 border border-white/20 rounded-full -translate-x-1/2 -translate-y-1/2 pointer-events-none"></div>
                  <!-- Goal Areas / Penalty Boxes -->
                  <div class="absolute top-4 left-1/2 -translate-x-1/2 w-80 h-32 border-b border-x border-white/10 pointer-events-none"></div>
                  <div class="absolute bottom-4 left-1/2 -translate-x-1/2 w-80 h-32 border-t border-x border-white/10 pointer-events-none"></div>

                  <% layout = Map.fetch!(@formation_layouts, @formation) %>
                  
                  <!-- Attacking Line -->
                  <div class="flex justify-around items-center gap-2 z-10 mt-2">
                    <%= for pos <- layout.fwd do %>
                      <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                        <%= if card = @lineup[pos] do %>
                          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                            {@position_names[pos]}
                          </div>
                          <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                            {truncate_name(card.player.display_name)}
                          </div>
                        <% else %>
                          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                            {@position_names[pos]}
                          </div>
                          <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
                            {@position_descriptions[pos]}
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                  
                  <!-- Midfield Line -->
                  <div class="flex justify-around items-center gap-2 z-10 my-4">
                    <%= for pos <- layout.mid do %>
                      <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                        <%= if card = @lineup[pos] do %>
                          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                            {@position_names[pos]}
                          </div>
                          <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                            {truncate_name(card.player.display_name)}
                          </div>
                        <% else %>
                          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                            {@position_names[pos]}
                          </div>
                          <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
                            {@position_descriptions[pos]}
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                  
                  <!-- Defensive Line -->
                  <div class="flex justify-around items-center gap-2 z-10">
                    <%= for pos <- layout.def do %>
                      <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                        <%= if card = @lineup[pos] do %>
                          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                            {@position_names[pos]}
                          </div>
                          <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                            {truncate_name(card.player.display_name)}
                          </div>
                        <% else %>
                          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                            {@position_names[pos]}
                          </div>
                          <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
                            {@position_descriptions[pos]}
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                  
                  <!-- Goalkeeper (GK) -->
                  <div class="flex justify-center items-center z-10 mb-2">
                    <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                      <%= if card = @lineup[:gk] do %>
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                          {@position_names[:gk]}
                        </div>
                        <div class="mt-2 px-3 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold max-w-[80px] sm:max-w-[100px] truncate shadow">
                          {truncate_name(card.player.display_name)}
                        </div>
                      <% else %>
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                          {@position_names[:gk]}
                        </div>
                        <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
                          {@position_descriptions[:gk]}
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>

                <!-- Standings table -->
                <% pts = @season_record.wins * 3 + @season_record.draws
                gd = @season_record.gf - @season_record.ga
                gd_str = if gd >= 0, do: "+#{gd}", else: "#{gd}"
                is_invincible = @season_record.losses == 0
                is_perfect = @season_record.wins == 38 %>
                <div id="standings-table-card">
                  <div class={[
                    "rounded-t-xl px-6 py-4 flex items-center justify-between",
                    if(is_perfect,
                      do: "bg-gradient-to-r from-[#cba258] to-[#f0d47c]",
                      else:
                        if(is_invincible,
                          do: "bg-gradient-to-r from-[#006241] to-[#00754A]",
                          else: "bg-gradient-to-r from-[#1a1a1a] to-[#333]"
                        )
                    )
                  ]}>
                    <div>
                      <div class="text-[10px] font-bold uppercase tracking-[1.2px] text-white/70 mb-0.5">
                        Shared Campaign <%= if @season_label do %>· {@season_label}<% end %>
                      </div>
                      <div class="text-white font-black text-2xl tracking-tight leading-none">
                        {if is_perfect,
                          do: "PERFECT SEASON",
                          else: if(is_invincible, do: "INVINCIBLES", else: "FINAL RECORD")}
                      </div>
                    </div>
                    <div class="text-right">
                      <div class="text-white/60 text-[10px] uppercase tracking-wider">Points</div>
                      <div class="text-white font-black text-3xl leading-none">{pts}</div>
                    </div>
                  </div>

                  <div class="bg-white border-x border-[rgba(0,0,0,0.08)] px-6 py-5">
                    <div class="grid grid-cols-5 gap-2 text-center mb-5">
                      <div class="flex flex-col gap-1">
                        <span class="text-[22px] font-black text-[#006241] leading-none">
                          {@season_record.wins}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          Won
                        </span>
                      </div>
                      <div class="flex flex-col gap-1">
                        <span class="text-[22px] font-black text-[rgba(0,0,0,0.5)] leading-none">
                          {@season_record.draws}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          Drawn
                        </span>
                      </div>
                      <div class="flex flex-col gap-1">
                        <span class={[
                          "text-[22px] font-black leading-none",
                          if(@season_record.losses == 0, do: "text-[#006241]", else: "text-[#c82014]")
                        ]}>
                          {@season_record.losses}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          Lost
                        </span>
                      </div>
                      <div class="flex flex-col gap-1">
                        <span class="text-[22px] font-black text-[rgba(0,0,0,0.75)] leading-none">
                          {@season_record.gf}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          GF
                        </span>
                      </div>
                      <div class="flex flex-col gap-1">
                        <span class={[
                          "text-[22px] font-black leading-none",
                          if(gd >= 0, do: "text-[#006241]", else: "text-[#c82014]")
                        ]}>
                          {gd_str}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          GD
                        </span>
                      </div>
                    </div>

                    <div class={[
                      "text-center text-sm sm:text-base leading-relaxed italic mt-3 px-4",
                      if(is_perfect,
                        do: "text-[#7a5c1e] font-semibold",
                        else:
                          if(is_invincible,
                            do: "text-[#006241] font-semibold",
                            else: "text-[rgba(0,0,0,0.78)] font-medium"
                          )
                      )
                    ]}>
                      "{@funny_quote}"
                    </div>
                  </div>

                  <div class="bg-[#f7f7f5] border border-[rgba(0,0,0,0.08)] rounded-b-xl px-6 py-4 flex items-center justify-between">
                    <span class="text-[10px] text-[rgba(0,0,0,0.4)]">
                      GA: {@season_record.ga} · Pts: {pts}
                    </span>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Right 4 columns: Play Call-To-Action -->
            <div class="order-1 lg:order-2 lg:col-span-4 flex flex-col gap-6">
              <div class="card-starbucks p-6 flex flex-col gap-6 text-center">
                <div class="w-12 h-12 mx-auto bg-[#edebe9] border border-[rgba(0,0,0,0.08)] rounded-[12px] flex items-center justify-center">
                  <.icon name="hero-trophy" class="w-6 h-6 text-[#00754A]" />
                </div>
                <h2 class="text-[20px] font-bold tracking-tight mb-2 text-[#006241]">
                  Build your own Invincibles squad!
                </h2>
                <p class="text-xs text-[rgba(0,0,0,0.58)] leading-relaxed mb-4">
                  Can you draft historical Premier League players and lead them to a perfect, undefeated 38-game season?
                </p>
                <.link navigate="/" class="w-full btn-starbucks btn-starbucks-filled text-sm block py-3">
                  PLAY NOW
                </.link>
              </div>
            </div>
          </main>
        </div>
      </Layouts.app>
      """
    end

    defp truncate_name(name) do
      case String.split(name, " ") do
        [single] -> single
        parts -> List.last(parts)
      end
    end
  end
  ```

- [ ] **Step 3: Verify compilation**
  Run: `mix compile`
  Expected: Compiles successfully.

- [ ] **Step 4: Commit**
  ```bash
  git add lib/invincibles_web/live/share_live.ex
  git commit -m "feat: implement ShareLive LiveView"
  ```

---

### Task 6: Add ShareRoute to Router

**Files:**
- Modify: `lib/invincibles_web/router.ex`
- Test: Verify routing works using compilation check

- [ ] **Step 1: Add Route for ShareLive**
  Map route `/share/:id` to `ShareLive` inside the main browser scope block.

  *Modify `lib/invincibles_web/router.ex`:*
  ```elixir
    scope "/", InvinciblesWeb do
      pipe_through :browser

      live "/", GameLive
      live "/share/:id", ShareLive
    end
  ```

- [ ] **Step 2: Verify compilation**
  Run: `mix compile`
  Expected: Compiles successfully.

- [ ] **Step 3: Commit**
  ```bash
  git add lib/invincibles_web/router.ex
  git commit -m "feat: add share route"
  ```

---

### Task 7: Integrate Share Event and Button Action

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`
- Modify: `assets/js/app.js`

- [ ] **Step 1: Implement `"share_lineup"` LiveView Event**
  Add event handler to `GameLive` that creates the db share record and pushes the URL back to the JS hook.

  *Append this function inside the implementation block of `lib/invincibles_web/live/game_live.ex`:*
  ```elixir
    @impl true
    def handle_event("share_lineup", _params, socket) do
      lineup = socket.assigns.lineup
      formation = socket.assigns.formation
      record = socket.assigns.season_record
      season_label = if socket.assigns.sim_results, do: Map.get(socket.assigns.sim_results, :season_label, ""), else: ""
      funny_quote = get_funny_quote(record)

      case Game.create_share(lineup, formation, record, season_label, funny_quote) do
        {:ok, share} ->
          url = url(~p"/share/#{share.id}")
          {:noreply, push_event(socket, "share_url", %{url: url})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to generate share link.")}
      end
    end
  ```

- [ ] **Step 2: Update the ShareButton JS Hook**
  Modify hook to push the event to LiveView and register a `share_url` callback.

  *Modify `ShareButton` hook inside `assets/js/app.js`:*
  ```javascript
    ShareButton: {
      mounted() {
        this.el.addEventListener("click", () => {
          const originalText = this.el.innerHTML;
          this.el.disabled = true;
          this.el.innerHTML = "Generating Link...";

          this.pushEvent("share_lineup", {});

          this._originalText = originalText;
        });

        this.handleEvent("share_url", ({ url }) => {
          this.el.disabled = false;
          if (this._originalText) {
            this.el.innerHTML = this._originalText;
          }

          const wins = this.el.dataset.wins || "0";
          const draws = this.el.dataset.draws || "0";
          const losses = this.el.dataset.losses || "0";
          const points = this.el.dataset.points || "0";
          const season = this.el.dataset.season ? ` (${this.el.dataset.season})` : "";
          const quote = this.el.dataset.quote || "";

          let text = `Can you build a squad and go 38-0-0? Check out my Invincibles campaign!\n\nLink: ${url}\n\nRecord: ${wins}W - ${draws}D - ${losses}L | ${points} Pts${season} ⚽🏆`;
          if (quote) {
            text += `\n\n"${quote}"`;
          }
          text += `\n\n#InvinciblesDraft`;

          const tweetText = encodeURIComponent(text);
          const twitterUrl = `https://twitter.com/intent/tweet?text=${tweetText}`;
          window.open(twitterUrl, "_blank");
        });
      }
    },
  ```

- [ ] **Step 3: Test integration**
  Run: `mix test`
  Expected: All tests pass.

- [ ] **Step 4: Commit**
  ```bash
  git add lib/invincibles_web/live/game_live.ex assets/js/app.js
  git commit -m "feat: hook up ShareButton event flow"
  ```

---

### Task 8: LiveView Share Redirect Integration Tests

**Files:**
- Create: `test/invincibles_web/live/share_live_test.exs`

- [ ] **Step 1: Write integration tests**
  Test that navigating to a valid share renders content, and navigating to an invalid share redirects to "/" with an error message.

  *Content for `test/invincibles_web/live/share_live_test.exs`:*
  ```elixir
  defmodule InvinciblesWeb.ShareLiveTest do
    use InvinciblesWeb.ConnCase
    import Phoenix.LiveViewTest
    alias Invincibles.Repo
    alias Invincibles.Game

    # Setup database record
    setup do
      club = Repo.insert!(%Invincibles.Game.Club{name: "Integration Share FC", short_name: "ISFC", primary_color: "#111"})
      player = Repo.insert!(%Invincibles.Game.Player{name: "Test Int", display_name: "T. Int", primary_position: "GK"})
      appearance = Repo.insert!(%Invincibles.Game.Appearance{player: player, club: club, season: "2023-24", era: "Modern", ovr: 88, stats: %{}})
      
      {:ok, appearance: appearance}
    end

    test "ShareLive renders shared lineup card successfully", %{conn: conn, appearance: app} do
      lineup = %{gk: app}
      record = %{wins: 38, draws: 0, losses: 0, gf: 110, ga: 10, week: 38}
      funny_quote = "Perfect Run"

      {:ok, share} = Game.create_share(lineup, "4-3-3", record, "2023-24", funny_quote)

      {:ok, _view, html} = live(conn, ~p"/share/#{share.id}")
      assert html =~ "T. Int"
      assert html =~ "Perfect Run"
      assert html =~ "38W - 0D - 0L"
    end

    test "ShareLive redirects to homepage on invalid or missing share ID", %{conn: conn} do
      random_uuid = Ecto.UUID.generate()
      
      # Assert redirect occurs to "/"
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/share/#{random_uuid}")
    end
  end
  ```

- [ ] **Step 2: Run tests**
  Run: `mix test test/invincibles_web/live/share_live_test.exs`
  Expected: PASS

- [ ] **Step 3: Commit**
  ```bash
  git add test/invincibles_web/live/share_live_test.exs
  git commit -m "test: add ShareLive integration tests"
  ```
