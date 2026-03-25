defmodule Singularity.Permissions do
  @moduledoc """
  Context for managing permission grants between users and for agent access.
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Permissions.Permission

  @doc """
  Grant a user access to a resource.
  Upserts — if a grant already exists, updates the access level.
  """
  def grant_access(attrs) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:access_level, :updated_at]},
      conflict_target: [:grantor_id, :grantee_id, :resource_type, :resource_id]
    )
  end

  @doc """
  Revoke access by setting level to :none or deleting the grant.
  """
  def revoke_access(grantor_id, grantee_id, resource_type, resource_id) do
    Permission
    |> where(grantor_id: ^grantor_id, grantee_id: ^grantee_id,
             resource_type: ^resource_type, resource_id: ^resource_id)
    |> Repo.delete_all()
  end

  @doc """
  Check if a user has at least the given access level to a resource.
  """
  def has_access?(user_id, resource_type, resource_id, required_level) do
    level_rank = %{"none" => 0, "metadata" => 1, "read" => 2, "write" => 3}
    required_rank = Map.get(level_rank, required_level, 0)

    grant =
      Permission
      |> where(grantee_id: ^user_id, resource_type: ^resource_type, resource_id: ^resource_id)
      |> Repo.one()

    case grant do
      nil -> false
      %{access_level: level} -> Map.get(level_rank, level, 0) >= required_rank
    end
  end

  @doc """
  List all resources shared with a user.
  """
  def list_shared_with(user_id) do
    Permission
    |> where(grantee_id: ^user_id)
    |> where([p], p.access_level != "none")
    |> Repo.all()
    |> Repo.preload(:grantor)
  end

  @doc """
  List all grants a user has made.
  """
  def list_grants_by(user_id) do
    Permission
    |> where(grantor_id: ^user_id)
    |> where([p], p.access_level != "none")
    |> Repo.all()
    |> Repo.preload(:grantee)
  end
end
