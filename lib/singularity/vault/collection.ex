defmodule Singularity.Vault.Collection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "collections" do
    field :name, :string
    field :description, :string

    belongs_to :user, Singularity.Accounts.User
    has_many :items, Singularity.Vault.Item

    timestamps(type: :utc_datetime)
  end

  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name, :description, :user_id])
    |> validate_required([:name, :user_id])
    |> unique_constraint([:user_id, :name])
    |> foreign_key_constraint(:user_id)
  end
end
