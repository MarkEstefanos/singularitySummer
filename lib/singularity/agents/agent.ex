defmodule Singularity.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(inactive active running error)

  schema "agents" do
    field :name, :string
    field :description, :string
    field :system_prompt, :string
    field :status, :string, default: "inactive"
    field :config, :map, default: %{}

    belongs_to :user, Singularity.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:name, :description, :system_prompt, :status, :config, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
  end
end
