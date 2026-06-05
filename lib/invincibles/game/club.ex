defmodule Invincibles.Game.Club do
  use Ecto.Schema
  import Ecto.Changeset

  schema "clubs" do
    field :name, :string
    field :short_name, :string
    field :primary_color, :string

    has_many :appearances, Invincibles.Game.Appearance

    timestamps()
  end

  def changeset(club, attrs) do
    club
    |> cast(attrs, [:name, :short_name, :primary_color])
    |> validate_required([:name, :short_name, :primary_color])
    |> validate_length(:short_name, max: 4)
    |> unique_constraint(:name)
    |> unique_constraint(:short_name)
  end
end
