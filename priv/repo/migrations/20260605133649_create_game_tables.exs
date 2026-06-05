defmodule Invincibles.Repo.Migrations.CreateGameTables do
  use Ecto.Migration

  def change do
    create table(:clubs) do
      add :name, :string, null: false
      add :short_name, :string, size: 4, null: false
      add :primary_color, :string, null: false

      timestamps()
    end

    create unique_index(:clubs, [:name])
    create unique_index(:clubs, [:short_name])

    create table(:players) do
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :primary_position, :string, size: 2, null: false

      timestamps()
    end

    create index(:players, [:primary_position])

    create table(:appearances) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :club_id, references(:clubs, on_delete: :delete_all), null: false
      add :season, :string, null: false
      add :era, :string, null: false
      add :ovr, :integer, null: false
      add :stats, :map, null: false

      timestamps()
    end

    # Index FK columns per Supabase best practices
    create index(:appearances, [:player_id])
    create index(:appearances, [:club_id])
    # Composite index for drafting queries (filtering by club and era)
    create index(:appearances, [:club_id, :era])
  end
end
