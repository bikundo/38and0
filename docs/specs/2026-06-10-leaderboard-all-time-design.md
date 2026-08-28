# Leaderboard All-Time & Total Games Played Count Design

Modify the leaderboard to display the best campaigns of all time (rather than just the last 48 hours), disable the automatic campaign cleanup worker, and add a clean, text-only count of total games simulated on the leaderboard page.

## User Review Required

> [!IMPORTANT]
> The background worker `ShareCleanupWorker` will be completely disabled and removed from the application supervision tree. Old campaign records (shares) will no longer be deleted and will persist in the database indefinitely.

> [!IMPORTANT]
> The leaderboard page and share retrieval logic will be updated to fetch from all existing campaign records without filtering by the 48-hour age limit.

## Proposed Changes

### Database & Application Supervisor

#### [MODIFY] [application.ex](file:///lib/invincibles/application.ex)
* Remove `Invincibles.Game.ShareCleanupWorker` from the children supervision list.

#### [DELETE] [share_cleanup_worker.ex](file:///lib/invincibles/game/share_cleanup_worker.ex)
* Delete the cleanup worker module entirely as it is no longer required.

#### [DELETE] [share_cleanup_worker_test.exs](file:///test/invincibles/share_cleanup_worker_test.exs)
* Delete the cleanup worker unit tests.

### Game Context

#### [MODIFY] [game.ex](file:///lib/invincibles/game.ex)
* Update `get_share/1`: Remove the age-checking expiration check (deleting and returning `:error` if older than 48 hours). Allow any existing share to be loaded.
* Update `list_active_shares/0` (keeping the name for compatibility): Remove the 48-hour `inserted_at` filter clause so that it returns the top 20 best campaigns of all time.
* Add `count_all_shares/0`: A helper function that returns the total count of shares in the database.

### Game LiveView

#### [MODIFY] [game_live.ex](file:///lib/invincibles_web/live/game_live.ex)
* In `mount/3`, initialize `@total_games_played` to `0` inside `reset_state/1` or `mount/3`.
* In `handle_params/3`, when `tab == :leaderboard`, assign `shares: Game.list_active_shares()` and `total_games_played: Game.count_all_shares()`.
* Add a `number_to_delimited/1` helper to format the count with thousands separators (commas).
* In `render/1`, update the subtitle in the leaderboard layout to match Option A (badge-free, inline layout):
  ```heex
  The best campaigns from managers worldwide · {number_to_delimited(@total_games_played)} total games played
  ```

---

## Verification Plan

### Automated Tests
* Run `mix test` to verify all existing and modified tests compile and pass.
* Update existing leaderboard and share tests to assert against the all-time capability and count display.

### Manual Verification
* Access the leaderboard page `/??tab=leaderboard` in the browser.
* Verify that the subtitle displays "The best campaigns from managers worldwide · [X] total games played" cleanly.
* Complete a simulation run to trigger a new share record insertion, return to the leaderboard, and verify that the total games count increments by 1.
