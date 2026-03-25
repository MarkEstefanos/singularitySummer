defmodule Singularity.Vault do
  @moduledoc """
  Context for managing user data vaults — items with optional folder organization.
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Vault.{Collection, Item}

  # Items — primary API

  @doc """
  List items for a user with optional filtering.

  Options:
    - :folder_path - filter to a specific folder (nil = root / unfiled)
    - :all_folders - when true, list everything regardless of folder
  """
  def list_items_for_user(user_id, opts \\ []) do
    folder_path = Keyword.get(opts, :folder_path)
    all_folders = Keyword.get(opts, :all_folders, true)

    Item
    |> where(user_id: ^user_id)
    |> maybe_filter_folder(folder_path, all_folders)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  defp maybe_filter_folder(query, nil, true), do: query
  defp maybe_filter_folder(query, nil, false), do: where(query, [i], is_nil(i.folder_path))
  defp maybe_filter_folder(query, path, _), do: where(query, [i], i.folder_path == ^path)

  @doc """
  List distinct folder paths for a user.
  """
  def list_folders(user_id) do
    Item
    |> where(user_id: ^user_id)
    |> where([i], not is_nil(i.folder_path))
    |> select([i], i.folder_path)
    |> distinct(true)
    |> order_by([i], i.folder_path)
    |> Repo.all()
  end

  def get_item!(id), do: Repo.get!(Item, id)

  def create_item(attrs) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  def move_item(%Item{} = item, folder_path) do
    item
    |> Item.changeset(%{folder_path: folder_path})
    |> Repo.update()
  end

  def search_items(user_id, query) do
    Item
    |> where(user_id: ^user_id)
    |> where([i], ilike(i.name, ^"%#{query}%") or ilike(i.extracted_text, ^"%#{query}%"))
    |> Repo.all()
  end

  # Collections — kept for backward compatibility

  def list_collections(user_id) do
    Collection
    |> where(user_id: ^user_id)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_collection!(id), do: Repo.get!(Collection, id)

  def create_collection(attrs) do
    %Collection{}
    |> Collection.changeset(attrs)
    |> Repo.insert()
  end

  def delete_collection(%Collection{} = collection) do
    Repo.delete(collection)
  end

  def list_items(collection_id) do
    Item
    |> where(collection_id: ^collection_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end
end
