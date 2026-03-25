defmodule Singularity.Circles.Circle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "circles" do
    field :name, :string
    field :description, :string
    field :color, :string, default: "#6366f1"

    belongs_to :user, Singularity.Accounts.User
    many_to_many :members, Singularity.Accounts.User, join_through: "circle_members"

    timestamps(type: :utc_datetime)
  end

  def changeset(circle, attrs) do
    circle
    |> cast(attrs, [:name, :description, :color, :user_id])
    |> validate_required([:name, :user_id])
    |> unique_constraint([:user_id, :name])
    |> foreign_key_constraint(:user_id)
  end
end
