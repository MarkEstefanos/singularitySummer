defmodule Singularity.Repo.Migrations.CreatePermissions do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :access_level, :string, null: false, default: "none"
      add :grantor_id, references(:users, on_delete: :delete_all), null: false
      add :grantee_id, references(:users, on_delete: :delete_all), null: false

      # Polymorphic resource: either a collection or an item
      add :resource_type, :string, null: false
      add :resource_id, :id, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:permissions, [:grantor_id])
    create index(:permissions, [:grantee_id])
    create index(:permissions, [:resource_type, :resource_id])
    create unique_index(:permissions, [:grantor_id, :grantee_id, :resource_type, :resource_id])
  end
end
