defmodule Singularity.Repo.Migrations.CreateVaultTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"

    create table(:collections) do
      add :name, :string, null: false
      add :description, :text
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:collections, [:user_id])
    create unique_index(:collections, [:user_id, :name])

    create table(:items) do
      add :name, :string, null: false
      add :content_type, :string, null: false
      add :size_bytes, :bigint
      add :storage_path, :string
      add :metadata, :map, default: %{}
      add :extracted_text, :text
      add :embedding, :vector, size: 1536
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:items, [:collection_id])
    create index(:items, [:user_id])
    create index(:items, [:content_type])
  end
end
