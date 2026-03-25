defmodule Singularity.Repo.Migrations.CreateCircles do
  use Ecto.Migration

  def change do
    create table(:circles) do
      add :name, :string, null: false
      add :description, :text
      add :color, :string, default: "#6366f1"
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:circles, [:user_id])
    create unique_index(:circles, [:user_id, :name])

    create table(:circle_members) do
      add :circle_id, references(:circles, on_delete: :delete_all), null: false
      add :member_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:circle_members, [:circle_id])
    create index(:circle_members, [:member_id])
    create unique_index(:circle_members, [:circle_id, :member_id])

    # Sharing grants: share a resource with a circle at an access level
    create table(:circle_shares) do
      add :access_level, :string, null: false, default: "read"
      add :circle_id, references(:circles, on_delete: :delete_all), null: false
      add :resource_type, :string, null: false
      add :resource_id, :id, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:circle_shares, [:circle_id])
    create index(:circle_shares, [:resource_type, :resource_id])
    create unique_index(:circle_shares, [:circle_id, :resource_type, :resource_id])
  end
end
