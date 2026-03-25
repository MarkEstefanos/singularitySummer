defmodule Singularity.Circles.CircleShare do
  use Ecto.Schema
  import Ecto.Changeset

  @access_levels ~w(metadata read write)

  schema "circle_shares" do
    field :access_level, :string, default: "read"
    field :resource_type, :string
    field :resource_id, :integer

    belongs_to :circle, Singularity.Circles.Circle

    timestamps(type: :utc_datetime)
  end

  def changeset(share, attrs) do
    share
    |> cast(attrs, [:access_level, :resource_type, :resource_id, :circle_id])
    |> validate_required([:access_level, :resource_type, :resource_id, :circle_id])
    |> validate_inclusion(:access_level, @access_levels)
    |> validate_inclusion(:resource_type, ~w(collection item))
    |> unique_constraint([:circle_id, :resource_type, :resource_id])
  end
end
