defmodule Singularity.Repo.Migrations.CreateVaultTables do
  use Ecto.Migration

  def up do
    # pgvector may not be available on all hosts (e.g. Render free tier)
    execute """
    DO $$
    BEGIN
      CREATE EXTENSION IF NOT EXISTS vector;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgvector not available, embedding column will use bytea fallback';
    END $$;
    """

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
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Flush so tables and extensions are created before we check
    flush()

    embedding_type =
      if pgvector_available?(), do: "vector(1536)", else: "bytea"

    execute "ALTER TABLE items ADD COLUMN embedding #{embedding_type}"

    create index(:items, [:collection_id])
    create index(:items, [:user_id])
    create index(:items, [:content_type])
  end

  def down do
    drop table(:items)
    drop table(:collections)
  end

  defp pgvector_available? do
    result = repo().query("SELECT 1 FROM pg_extension WHERE extname = 'vector'")
    match?({:ok, %{num_rows: 1}}, result)
  end
end
