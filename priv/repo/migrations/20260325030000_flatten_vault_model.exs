defmodule Singularity.Repo.Migrations.FlattenVaultModel do
  use Ecto.Migration

  def change do
    alter table(:items) do
      modify :collection_id, :bigint, null: true,
        from: {references(:collections, on_delete: :delete_all), null: false}
      add :folder_path, :string
    end

    create index(:items, [:folder_path])
  end
end
