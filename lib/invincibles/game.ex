defmodule Invincibles.Game do
  @moduledoc """
  Context module for managing clubs, players, and appearances.
  """
  import Ecto.Query
  alias Invincibles.Repo
  alias Invincibles.Game.Club
  alias Invincibles.Game.Appearance

  @eras ["90s", "00s", "10s", "20s"]

  @doc """
  Randomly selects a club and era, then returns 4 random appearances matching them.
  Preloads the associated player and club.
  """
  def spin_wheel(eligible_positions \\ ["GK", "DF", "MF", "FW"]) do
    # Fetch all clubs to pick one randomly
    clubs = Repo.all(Club)
    
    if Enum.empty?(clubs) do
      {:error, :no_clubs}
    else
      club = Enum.random(clubs)
      era = Enum.random(@eras)

      # Fetch 4 random appearances matching club and era and position constraints
      appearances =
        from(a in Appearance,
          join: p in assoc(a, :player),
          where: a.club_id == ^club.id and a.era == ^era and p.primary_position in ^eligible_positions,
          order_by: fragment("RANDOM()"),
          limit: 4,
          preload: [:player, :club]
        )
        |> Repo.all()

      {:ok, club, era, appearances}
    end
  end

  @doc """
  Fetches an appearance by ID.
  """
  def get_appearance(id) do
    Repo.get(Appearance, id) |> Repo.preload([:player, :club])
  end

  @doc """
  Calculates the draft cost of a player based on their OVR rating.
  - OVR >= 90: Premium Legend (40M - 80M)
  - OVR 83-89: Rare Gold (15M - 33M)
  - OVR < 83: Common Silver/Slate (5M - 15M)
  """
  def calculate_cost(ovr) do
    cond do
      ovr >= 90 ->
        40_000_000 + (ovr - 90) * 8_000_000

      ovr >= 83 ->
        15_000_000 + (ovr - 83) * 3_000_000

      true ->
        5_000_000 + (ovr - 50) * 300_000
    end
  end
end
