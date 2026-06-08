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
