defmodule Singularity.Vault do
  @moduledoc """
  Context for managing user data vaults — collections and items.
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Vault.{Collection, Item}

  # Collections

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

  # Items

  def list_items(collection_id) do
    Item
    |> where(collection_id: ^collection_id)
    |> order_by(desc: :inserted_at)
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

  def search_items(user_id, query) do
    Item
    |> where(user_id: ^user_id)
    |> where([i], ilike(i.name, ^"%#{query}%") or ilike(i.extracted_text, ^"%#{query}%"))
    |> Repo.all()
  end
end
