defmodule Singularity.Agents.AgentPermission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agent_permissions" do
    field :access_level, :string, default: "read"
    field :resource_type, :string
    field :resource_id, :integer

    belongs_to :agent, Singularity.Agents.Agent

    timestamps(type: :utc_datetime)
  end

  def changeset(perm, attrs) do
    perm
    |> cast(attrs, [:access_level, :resource_type, :resource_id, :agent_id])
    |> validate_required([:access_level, :resource_type, :resource_id, :agent_id])
    |> validate_inclusion(:access_level, ~w(metadata read write))
    |> validate_inclusion(:resource_type, ~w(collection item))
    |> unique_constraint([:agent_id, :resource_type, :resource_id])
  end
end
