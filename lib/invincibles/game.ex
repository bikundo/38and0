defmodule Invincibles.Game do
  @moduledoc """
  Context module for managing clubs, players, and appearances.
  """
  import Ecto.Query
  alias Invincibles.Repo
  alias Invincibles.Game.Appearance

  @doc """
  Randomly selects a club and season from existing database appearances,
  then returns all appearances matching that club and season.
  Preloads the associated player and club.
  """
  def spin_wheel do
    top_6_names = ["Arsenal", "Manchester United", "Chelsea", "Liverpool", "Manchester City", "Tottenham Hotspur"]

    # 1. Fetch a random appearance from the DB to get a valid club + season (Top 6 only)
    random_app =
      from(a in Appearance,
        join: c in assoc(a, :club),
        where: c.name in ^top_6_names,
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
