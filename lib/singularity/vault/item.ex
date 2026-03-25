defmodule Singularity.Vault.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :name, :string
    field :content_type, :string
    field :size_bytes, :integer
    field :storage_path, :string
    field :metadata, :map, default: %{}
    field :extracted_text, :string
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :collection, Singularity.Vault.Collection
    belongs_to :user, Singularity.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :content_type, :size_bytes, :storage_path, :metadata,
                     :extracted_text, :embedding, :collection_id, :user_id])
    |> validate_required([:name, :content_type, :collection_id, :user_id])
    |> foreign_key_constraint(:collection_id)
    |> foreign_key_constraint(:user_id)
  end
end
