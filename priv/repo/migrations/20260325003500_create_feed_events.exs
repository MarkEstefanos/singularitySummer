defmodule Singularity.Repo.Migrations.CreateFeedEvents do
  use Ecto.Migration

  def change do
    create table(:feed_events) do
      add :verb, :string, null: false
      add :summary, :text
      add :metadata, :map, default: %{}

      # Actor — either a user or an agent
      add :actor_type, :string, null: false
      add :actor_id, :id, null: false

      # Object — the thing acted upon
      add :object_type, :string
      add :object_id, :id

      # Audience — list of user IDs who should see this event
      add :audience, {:array, :id}, default: []

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:feed_events, [:actor_type, :actor_id])
    create index(:feed_events, [:inserted_at])
    create index(:feed_events, [:audience], using: :gin)
  end
end
