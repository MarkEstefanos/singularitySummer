defmodule Singularity.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    create table(:agents) do
      add :name, :string, null: false
      add :description, :text
      add :system_prompt, :text
      add :status, :string, null: false, default: "inactive"
      add :config, :map, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:agents, [:user_id])

    # Agent permission grants — which collections/items an agent can access
    create table(:agent_permissions) do
      add :access_level, :string, null: false, default: "read"
      add :agent_id, references(:agents, on_delete: :delete_all), null: false
      add :resource_type, :string, null: false
      add :resource_id, :id, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:agent_permissions, [:agent_id])
    create unique_index(:agent_permissions, [:agent_id, :resource_type, :resource_id])
  end
end
