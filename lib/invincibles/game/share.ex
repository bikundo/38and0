defmodule Invincibles.Game.Share do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "shares" do
    field :formation, :string
    field :lineup, :map
    field :season_record, :map
    field :season_label, :string
    field :funny_quote, :string

    timestamps()
  end

  def changeset(share, attrs) do
    share
    |> cast(attrs, [:formation, :lineup, :season_record, :season_label, :funny_quote])
    |> validate_required([:formation, :lineup, :season_record, :funny_quote])
  end
end
