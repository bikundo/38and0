defmodule Invincibles.Repo.Migrations.CreateShares do
  use Ecto.Migration

  def change do
    create table(:shares, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :formation, :string, null: false
      add :lineup, :map, null: false
      add :season_record, :map, null: false
      add :season_label, :string
      add :funny_quote, :text, null: false

      timestamps()
    end
  end
end
