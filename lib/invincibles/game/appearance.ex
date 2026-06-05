defmodule Invincibles.Game.Appearance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appearances" do
    field :season, :string
    field :era, :string
    field :ovr, :integer
    field :stats, :map

    belongs_to :player, Invincibles.Game.Player
    belongs_to :club, Invincibles.Game.Club

    timestamps()
  end

  def changeset(appearance, attrs) do
    appearance
    |> cast(attrs, [:player_id, :club_id, :season, :era, :ovr, :stats])
    |> validate_required([:player_id, :club_id, :season, :era, :ovr, :stats])
    |> validate_inclusion(:era, ["90s", "00s", "10s", "20s"])
    |> validate_number(:ovr, greater_than_or_equal_to: 50, less_than_or_equal_to: 99)
    |> validate_stats()
  end

  defp validate_stats(changeset) do
    stats = get_field(changeset, :stats)

    cond do
      is_nil(stats) ->
        add_error(changeset, :stats, "can't be blank")

      not is_map(stats) ->
        add_error(changeset, :stats, "must be a map")

      true ->
        # We will check keys based on position. Since loading player may not happen inside the changeset,
        # we can validate general stats presence of either goalkeeper stats (div, han, kic, ref, spd, pos)
        # or outfield stats (pac, sho, pas, dri, def, phy).
        keys = Map.keys(stats) |> Enum.map(&to_string/1)

        gk_keys = ["div", "han", "kic", "ref", "spd", "pos"]
        outfield_keys = ["pac", "sho", "pas", "dri", "def", "phy"]

        has_gk = Enum.all?(gk_keys, &Enum.member?(keys, &1))
        has_outfield = Enum.all?(outfield_keys, &Enum.member?(keys, &1))

        if has_gk or has_outfield do
          # Check all values are integers between 1 and 99
          invalid_stat =
            Enum.find(stats, fn {_, val} ->
              not is_integer(val) or val < 1 or val > 99
            end)

          if invalid_stat do
            add_error(changeset, :stats, "all stat attributes must be integers between 1 and 99")
          else
            changeset
          end
        else
          add_error(changeset, :stats, "must contain either all GK stats (div, han, kic, ref, spd, pos) or all outfield stats (pac, sho, pas, dri, def, phy)")
        end
    end
  end
end
