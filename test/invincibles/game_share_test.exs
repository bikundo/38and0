defmodule Invincibles.GameShareTest do
  use Invincibles.DataCase
  alias Invincibles.Game
  import Ecto.Query

  # Create helper mock player and club to draft
  setup do
    club =
      Repo.insert!(%Invincibles.Game.Club{
        name: "Test Share FC",
        short_name: "TSFC",
        primary_color: "#000"
      })

    player =
      Repo.insert!(%Invincibles.Game.Player{
        name: "John Share",
        display_name: "J. Share",
        primary_position: "FW"
      })

    appearance =
      Repo.insert!(%Invincibles.Game.Appearance{
        player: player,
        club: club,
        season: "2023-24",
        era: "Modern",
        ovr: 85,
        stats: %{}
      })

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
    assert retrieved.season_record[:wins] == 30
    assert retrieved.lineup[:st].id == app.id
  end

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
end
