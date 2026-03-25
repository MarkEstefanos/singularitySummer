defmodule Singularity.Circles do
  @moduledoc """
  Context for managing circles — named groups of users for sharing.
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Circles.{Circle, CircleMember, CircleShare}

  # Circles CRUD

  def list_circles(user_id) do
    Circle
    |> where(user_id: ^user_id)
    |> order_by(:name)
    |> Repo.all()
    |> Repo.preload(:members)
  end

  def get_circle!(id), do: Repo.get!(Circle, id) |> Repo.preload(:members)

  def create_circle(attrs) do
    %Circle{}
    |> Circle.changeset(attrs)
    |> Repo.insert()
  end

  def update_circle(%Circle{} = circle, attrs) do
    circle
    |> Circle.changeset(attrs)
    |> Repo.update()
  end

  def delete_circle(%Circle{} = circle) do
    Repo.delete(circle)
  end

  # Members

  def add_member(circle_id, user_id) do
    %CircleMember{}
    |> CircleMember.changeset(%{circle_id: circle_id, member_id: user_id})
    |> Repo.insert()
  end

  def remove_member(circle_id, user_id) do
    CircleMember
    |> where(circle_id: ^circle_id, member_id: ^user_id)
    |> Repo.delete_all()
  end

  def list_members(circle_id) do
    CircleMember
    |> where(circle_id: ^circle_id)
    |> Repo.all()
    |> Repo.preload(:member)
  end

  # Sharing

  def share_with_circle(attrs) do
    %CircleShare{}
    |> CircleShare.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:access_level, :updated_at]},
      conflict_target: [:circle_id, :resource_type, :resource_id]
    )
  end

  def unshare_with_circle(circle_id, resource_type, resource_id) do
    CircleShare
    |> where(circle_id: ^circle_id, resource_type: ^resource_type, resource_id: ^resource_id)
    |> Repo.delete_all()
  end

  def list_shares_for_resource(resource_type, resource_id) do
    CircleShare
    |> where(resource_type: ^resource_type, resource_id: ^resource_id)
    |> Repo.all()
    |> Repo.preload(circle: :members)
  end

  @doc """
  Check if a user has access to a resource through any circle.
  Returns the highest access level or nil.
  """
  def check_access(user_id, resource_type, resource_id) do
    level_rank = %{"metadata" => 1, "read" => 2, "write" => 3}

    shares =
      CircleShare
      |> where(resource_type: ^resource_type, resource_id: ^resource_id)
      |> join(:inner, [s], cm in CircleMember, on: cm.circle_id == s.circle_id)
      |> where([_s, cm], cm.member_id == ^user_id)
      |> select([s, _cm], s.access_level)
      |> Repo.all()

    shares
    |> Enum.max_by(fn level -> Map.get(level_rank, level, 0) end, fn -> nil end)
  end

  @doc """
  List all resources shared with a user through their circle memberships.
  """
  def list_shared_with_user(user_id) do
    CircleShare
    |> join(:inner, [s], cm in CircleMember, on: cm.circle_id == s.circle_id)
    |> where([_s, cm], cm.member_id == ^user_id)
    |> preload([s, _cm], circle: :members)
    |> Repo.all()
  end

  @doc """
  List circles a user belongs to (as a member, not owner).
  """
  def list_memberships(user_id) do
    Circle
    |> join(:inner, [c], cm in CircleMember, on: cm.circle_id == c.id)
    |> where([_c, cm], cm.member_id == ^user_id)
    |> Repo.all()
    |> Repo.preload([:members, :user])
  end
end
