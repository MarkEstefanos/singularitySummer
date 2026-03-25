defmodule Singularity.Permissions.Permission do
  use Ecto.Schema
  import Ecto.Changeset

  @access_levels ~w(none metadata read write)

  schema "permissions" do
    field :access_level, :string, default: "none"
    field :resource_type, :string
    field :resource_id, :integer

    belongs_to :grantor, Singularity.Accounts.User
    belongs_to :grantee, Singularity.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:access_level, :resource_type, :resource_id, :grantor_id, :grantee_id])
    |> validate_required([:access_level, :resource_type, :resource_id, :grantor_id, :grantee_id])
    |> validate_inclusion(:access_level, @access_levels)
    |> validate_inclusion(:resource_type, ~w(collection item))
    |> unique_constraint([:grantor_id, :grantee_id, :resource_type, :resource_id])
  end
end
