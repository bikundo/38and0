defmodule Invincibles.Game.Player do
  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do
    field :name, :string
    field :display_name, :string
    field :primary_position, :string

    has_many :appearances, Invincibles.Game.Appearance

    timestamps()
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :display_name, :primary_position])
    |> validate_required([:name, :display_name, :primary_position])
    |> validate_inclusion(:primary_position, ["GK", "DF", "MF", "FW"])
  end
end
