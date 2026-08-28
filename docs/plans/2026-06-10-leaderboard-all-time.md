# Leaderboard All-Time & Total Games Played Count Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modify the leaderboard to fetch and display the best campaigns of all time, disable the automatic database cleanup of campaign records (shares), and add a clean total games count inline on the leaderboard header.

**Architecture:** Disable the `ShareCleanupWorker` in the supervision tree, delete its files, update the Ecto query in `Game.list_active_shares/0` to retrieve all shares without age bounds, remove age expiration logic from `Game.get_share/1`, introduce a total campaigns count helper `Game.count_all_shares/0`, and update the `GameLive` view to assign and render the formatted total count in a clean text layout.

**Tech Stack:** Elixir, Phoenix LiveView 1.8, Ecto, PostgreSQL.

---

### Task 1: Disable and Delete Automatic Cleanup Worker

We will disable the automatic share cleanup by removing `ShareCleanupWorker` from the supervision list and deleting its module and test files.

**Files:**
- Modify: `lib/invincibles/application.ex`
- Delete: `lib/invincibles/game/share_cleanup_worker.ex`
- Delete: `test/invincibles/share_cleanup_worker_test.exs`

- [ ] **Step 1: Modify application.ex to remove ShareCleanupWorker**
  Open [application.ex](file:///lib/invincibles/application.ex) and remove the `Invincibles.Game.ShareCleanupWorker` atom from the `children` list.
  
  Replace lines 15-16:
  ```elixir
      # Start share cleanup worker
      Invincibles.Game.ShareCleanupWorker,
  ```
  with:
  ```elixir
      # Share cleanup worker has been disabled
  ```

- [ ] **Step 2: Delete share_cleanup_worker.ex**
  Remove the file [share_cleanup_worker.ex](file:///lib/invincibles/game/share_cleanup_worker.ex).

- [ ] **Step 3: Delete share_cleanup_worker_test.exs**
  Remove the file [share_cleanup_worker_test.exs](file:///test/invincibles/share_cleanup_worker_test.exs).

- [ ] **Step 4: Commit changes**
  ```bash
  git rm lib/invincibles/game/share_cleanup_worker.ex test/invincibles/share_cleanup_worker_test.exs
  git add lib/invincibles/application.ex
  git commit -m "feat: disable and remove automatic share cleanup worker"
  ```

---

### Task 2: Update Game Context for All-Time Shares and Count Helper

We will update the `Game` context functions to query all shares without age restriction, allow retrieval of any share, and count total shares in the database.

**Files:**
- Modify: `lib/invincibles/game.ex`
- Modify: `test/invincibles/game_share_test.exs`

- [ ] **Step 5: Update list_active_shares/0 and get_share/1, and add count_all_shares/0**
  Open [game.ex](file:///lib/invincibles/game.ex).
  
  1. Update `list_active_shares/0` to remove the query filter `where: s.inserted_at > ^two_days_ago_naive`.
  2. Update `get_share/1` to remove the age diff checking and deletion logic.
  3. Add `count_all_shares/0` function at the end of the module.
  
  Target block inside `get_share/1` (lines 287-326):
  ```elixir
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
  Replacement block:
  ```elixir
  def get_share(id) do
    case Repo.get(Share, id) do
      nil ->
        :error

      share ->
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
  ```
  
  Target block inside `list_active_shares/0` (lines 336-361):
  ```elixir
  def list_active_shares do
    two_days_ago_naive = NaiveDateTime.utc_now() |> NaiveDateTime.add(-172_800, :second)

    from(s in Share,
      where: s.inserted_at > ^two_days_ago_naive,
      order_by: [
        desc:
          fragment(
            "coalesce((?->>'wins')::integer, 0) * 3 + coalesce((?->>'draws')::integer, 0)",
            s.season_record,
            s.season_record
          ),
        asc: fragment("coalesce((?->>'losses')::integer, 0)", s.season_record),
        desc:
          fragment(
            "coalesce((?->>'gf')::integer, 0) - coalesce((?->>'ga')::integer, 0)",
            s.season_record,
            s.season_record
          ),
        desc: fragment("coalesce((?->>'wins')::integer, 0)", s.season_record),
        desc: s.inserted_at
      ],
      limit: 20
    )
    |> Repo.all()
  end
  ```
  Replacement block:
  ```elixir
  def list_active_shares do
    from(s in Share,
      order_by: [
        desc:
          fragment(
            "coalesce((?->>'wins')::integer, 0) * 3 + coalesce((?->>'draws')::integer, 0)",
            s.season_record,
            s.season_record
          ),
        asc: fragment("coalesce((?->>'losses')::integer, 0)", s.season_record),
        desc:
          fragment(
            "coalesce((?->>'gf')::integer, 0) - coalesce((?->>'ga')::integer, 0)",
            s.season_record,
            s.season_record
          ),
        desc: fragment("coalesce((?->>'wins')::integer, 0)", s.season_record),
        desc: s.inserted_at
      ],
      limit: 20
    )
    |> Repo.all()
  end
  ```
  
  Add `count_all_shares/0` context helper (before club helper functions):
  ```elixir
  @doc """
  Counts the total number of shared game records in the database.
  """
  def count_all_shares do
    Repo.aggregate(Share, :count, :id)
  end
  ```

- [ ] **Step 6: Update game_share_test.exs to test count and non-expiration**
  Open [game_share_test.exs](file:///test/invincibles/game_share_test.exs).
  Update `test "get_share/1 deletes and rejects expired share"` to check that old shares are *not* deleted or expired, and add a test for `count_all_shares/0`.
  
  Target block (lines 49-74):
  ```elixir
    test "get_share/1 deletes and rejects expired share" do
    # Insert share with manually backdated inserted_at
    # > 48 hours
    backdated = NaiveDateTime.utc_now() |> NaiveDateTime.add(-172_900, :second)

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
    {1, _} =
      Repo.update_all(from(s in Invincibles.Game.Share, where: s.id == ^share.id),
        set: [inserted_at: backdated]
      )

    assert Game.get_share(share.id) == :error
    # Check that it got deleted
    assert Repo.get(Invincibles.Game.Share, share.id) == nil
  end
  ```
  Replacement block:
  ```elixir
    test "get_share/1 retrieves backdated shares without expiring them" do
    # Insert share with manually backdated inserted_at
    # > 48 hours
    backdated = NaiveDateTime.utc_now() |> NaiveDateTime.add(-172_900, :second)

    {:ok, share} =
      %Invincibles.Game.Share{}
      |> Invincibles.Game.Share.changeset(%{
        formation: "4-3-3",
        lineup: %{"gk" => nil},
        season_record: %{"wins" => 0, "draws" => 0, "losses" => 0, "gf" => 0, "ga" => 0},
        season_label: "2023-24",
        funny_quote: "Not Expired"
      })
      |> Repo.insert()

    # Overwrite inserted_at
    {1, _} =
      Repo.update_all(from(s in Invincibles.Game.Share, where: s.id == ^share.id),
        set: [inserted_at: backdated]
      )

    assert {:ok, retrieved} = Game.get_share(share.id)
    assert retrieved.funny_quote == "Not Expired"
    assert Repo.get(Invincibles.Game.Share, share.id) != nil
  end

  test "count_all_shares/0 returns correct number of shares" do
    initial_count = Game.count_all_shares()

    {:ok, _share} =
      Game.create_share(
        %{gk: nil},
        "4-3-3",
        %{wins: 0, draws: 0, losses: 0, gf: 0, ga: 0, week: 38},
        "Season A",
        "Quote"
      )

    assert Game.count_all_shares() == initial_count + 1
  end
  ```

- [ ] **Step 7: Run context tests**
  Run: `mix test test/invincibles/game_share_test.exs`
  Expected: PASS

- [ ] **Step 8: Commit changes**
  ```bash
  git add lib/invincibles/game.ex test/invincibles/game_share_test.exs
  git commit -m "feat: allow all-time shares and add count_all_shares helper"
  ```

---

### Task 3: Display Total Games Count on Leaderboard Page

We will assign the total games count to the LiveView socket and render it inline in the header of the leaderboard.

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`
- Modify: `test/invincibles_web/live/leaderboard_test.exs`

- [ ] **Step 9: Assign total_games_played and define number formatter**
  Open [game_live.ex](file:///lib/invincibles_web/live/game_live.ex).
  
  1. Add `|> assign(:total_games_played, 0)` in `reset_state/1`.
  
  Target block in `reset_state/1` (lines 170-171):
  ```elixir
      |> assign(:shares, [])
      |> assign(:active_share, nil)
  ```
  Replacement block:
  ```elixir
      |> assign(:shares, [])
      |> assign(:active_share, nil)
      |> assign(:total_games_played, 0)
  ```

  2. Modify `handle_params/3` for the `:leaderboard` tab to load the count.
  
  Target block in `handle_params/3` (lines 78-84):
  ```elixir
      socket =
        if tab == :leaderboard do
          shares = Game.list_active_shares()
          assign(socket, shares: shares)
        else
          socket
        end
  ```
  Replacement block:
  ```elixir
      socket =
        if tab == :leaderboard do
          shares = Game.list_active_shares()
          total_games = Game.count_all_shares()

          socket
          |> assign(shares: shares)
          |> assign(total_games_played: total_games)
        else
          socket
        end
  ```

  3. Add the `number_to_delimited/1` helper function at the bottom of the file (before `@impl true def render(assigns)` or at the end of the module helper functions).
  
  Target block (line 575):
  ```elixir
      end
    end
  
    @impl true
    def render(assigns) do
  ```
  Replacement block:
  ```elixir
      end
    end

    defp number_to_delimited(num) when is_integer(num) do
      num
      |> Integer.to_charlist()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()
    end
  
    @impl true
    def render(assigns) do
  ```

  4. Update the subtitle block in `render/1`.
  
  Target block (lines 595-597):
  ```heex
                      <p class="text-xs text-[rgba(0,0,0,0.58)] mt-0.5">
                        The best campaigns from managers worldwide over the last 48 hours.
                      </p>
  ```
  Replacement block:
  ```heex
                      <p class="text-xs text-[rgba(0,0,0,0.58)] mt-0.5 font-medium">
                        The best campaigns from managers worldwide · {number_to_delimited(@total_games_played)} total games played
                      </p>
  ```

- [ ] **Step 10: Update leaderboard tests to check count display**
  Open [leaderboard_test.exs](file:///test/invincibles_web/live/leaderboard_test.exs) and add assertions that check the inline text matches "total games played".
  
  Target block (lines 35-39):
  ```elixir
    test "Leaderboard displays empty state when no shares exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")
      assert html =~ "No campaigns active"
      assert html =~ "Manager Leaderboard"
    end
  ```
  Replacement block:
  ```elixir
    test "Leaderboard displays empty state when no shares exist and displays 0 total games played", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")
      assert html =~ "No campaigns active"
      assert html =~ "Manager Leaderboard"
      assert html =~ "0 total games played"
    end
  ```

  And add verification to `test "Leaderboard lists shares in correct sorted order"`:
  Target block (lines 56-59):
  ```elixir
      {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")
  
      # Verify the manager leaderboard title is present
      assert html =~ "Manager Leaderboard"
  ```
  Replacement block:
  ```elixir
      {:ok, _view, html} = live(conn, ~p"/?tab=leaderboard")
  
      # Verify the manager leaderboard title is present and total count matches 3
      assert html =~ "Manager Leaderboard"
      assert html =~ "3 total games played"
  ```

- [ ] **Step 11: Run LiveView leaderboard tests**
  Run: `mix test test/invincibles_web/live/leaderboard_test.exs`
  Expected: PASS

- [ ] **Step 12: Commit changes**
  ```bash
  git add lib/invincibles_web/live/game_live.ex test/invincibles_web/live/leaderboard_test.exs
  git commit -m "feat: show formatted total games played on the leaderboard page"
  ```

---

### Task 4: Final Verification

Run all test suites and perform final check-up.

- [ ] **Step 13: Run mix precommit**
  Run: `mix precommit`
  Expected: All tests pass with no warnings/errors.
