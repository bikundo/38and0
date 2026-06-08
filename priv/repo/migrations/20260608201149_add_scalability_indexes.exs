defmodule Invincibles.Repo.Migrations.AddScalabilityIndexes do
  use Ecto.Migration

  def change do
    # The existing composite index (club_id, era) is unused — every query filters by season, not era.
    # Replace with (club_id, season) which covers the majority of hot-path queries:
    #   - fetch_appearances_for_spin, calculate_opponent_strengths,
    #   - list_appearances_for_club_and_season, list_appearances_for_spin,
    #   - list_seasons_for_club
    drop index(:appearances, [:club_id, :era])
    create index(:appearances, [:club_id, :season])

    # Standalone season index for queries that filter only by season:
    #   - select_random_season (DISTINCT season)
    #   - get_clubs_for_season (WHERE season = ?)
    #   - spin_wheel GROUP BY (club_id, season)
    create index(:appearances, [:season])

    # Covering index for the auto_draft hot path:
    #   WHERE ovr >= 80 AND player_id NOT IN (...)
    # Partial index on ovr >= 80 keeps it small
    create index(:appearances, [:player_id, :ovr],
             where: "ovr >= 80",
             name: "appearances_draftable_player_ovr_idx"
           )

    # shares(inserted_at) for leaderboard queries and cleanup worker:
    #   - list_active_shares: WHERE inserted_at > ? ORDER BY ... LIMIT 20
    #   - ShareCleanupWorker: WHERE inserted_at < ? (bulk delete)
    create index(:shares, [:inserted_at])
  end
end
