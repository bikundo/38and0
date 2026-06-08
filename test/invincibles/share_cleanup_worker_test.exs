defmodule Invincibles.Game.ShareCleanupWorkerTest do
  use Invincibles.DataCase
  alias Invincibles.Game.Share
  alias Invincibles.Game.ShareCleanupWorker
  import Ecto.Query

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

    {1, _} =
      Repo.update_all(from(s in Share, where: s.id == ^expired.id), set: [inserted_at: backdated])

    # Manually call handle_info on the cleanup worker
    {:noreply, _state} = ShareCleanupWorker.handle_info(:cleanup, %{})

    # Verify expired is gone, active remains
    assert Repo.get(Share, active.id) != nil
    assert Repo.get(Share, expired.id) == nil
  end
end
