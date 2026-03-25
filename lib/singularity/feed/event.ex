defmodule Singularity.Feed.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @verbs ~w(uploaded shared coordinated commented agent_action permission_granted)

  schema "feed_events" do
    field :verb, :string
    field :summary, :string
    field :metadata, :map, default: %{}
    field :actor_type, :string
    field :actor_id, :integer
    field :object_type, :string
    field :object_id, :integer
    field :audience, {:array, :integer}, default: []

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:verb, :summary, :metadata, :actor_type, :actor_id,
                     :object_type, :object_id, :audience])
    |> validate_required([:verb, :actor_type, :actor_id, :audience])
    |> validate_inclusion(:verb, @verbs)
    |> validate_inclusion(:actor_type, ~w(user agent))
  end
end
