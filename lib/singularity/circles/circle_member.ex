defmodule Singularity.Circles.CircleMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "circle_members" do
    belongs_to :circle, Singularity.Circles.Circle
    belongs_to :member, Singularity.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:circle_id, :member_id])
    |> validate_required([:circle_id, :member_id])
    |> unique_constraint([:circle_id, :member_id])
  end
end
