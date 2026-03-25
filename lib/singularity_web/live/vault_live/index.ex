defmodule SingularityWeb.VaultLive.Index do
  use SingularityWeb, :live_view

  alias Singularity.Vault

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    collections = Vault.list_collections(user_id)

    {:ok,
     assign(socket,
       page_title: "Vault",
       collections: collections,
       show_new_form: false,
       new_collection_name: "",
       new_collection_desc: ""
     )}
  end

  @impl true
  def handle_event("toggle-new-form", _params, socket) do
    {:noreply, assign(socket, show_new_form: !socket.assigns.show_new_form)}
  end

  def handle_event("create-collection", %{"name" => name, "description" => desc}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Vault.create_collection(%{name: name, description: desc, user_id: user_id}) do
      {:ok, _collection} ->
        collections = Vault.list_collections(user_id)

        {:noreply,
         socket
         |> assign(collections: collections, show_new_form: false)
         |> put_flash(:info, "Collection created")}

      {:error, changeset} ->
        msg = error_message(changeset)
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("delete-collection", %{"id" => id}, socket) do
    collection = Vault.get_collection!(id)
    {:ok, _} = Vault.delete_collection(collection)
    user_id = socket.assigns.current_scope.user.id
    collections = Vault.list_collections(user_id)
    {:noreply, assign(socket, collections: collections) |> put_flash(:info, "Collection deleted")}
  end

  defp error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Vault</h1>
          <button class="btn btn-primary btn-sm" phx-click="toggle-new-form">
            <.icon name="hero-plus" class="size-4" /> New Collection
          </button>
        </div>

        <!-- New collection form -->
        <div :if={@show_new_form} class="card bg-base-200">
          <div class="card-body">
            <form phx-submit="create-collection" class="flex flex-col gap-3">
              <div class="form-control">
                <label class="label"><span class="label-text">Name</span></label>
                <input
                  type="text"
                  name="name"
                  class="input input-bordered"
                  placeholder="e.g. Photos, Documents, Calendar"
                  required
                  phx-mounted={JS.focus()}
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Description (optional)</span></label>
                <input
                  type="text"
                  name="description"
                  class="input input-bordered"
                  placeholder="What goes in this collection?"
                />
              </div>
              <div class="flex gap-2">
                <button type="submit" class="btn btn-primary btn-sm">Create</button>
                <button type="button" class="btn btn-ghost btn-sm" phx-click="toggle-new-form">Cancel</button>
              </div>
            </form>
          </div>
        </div>

        <!-- Collections grid -->
        <div :if={@collections == []} class="text-base-content/60 py-12 text-center">
          <.icon name="hero-archive-box" class="size-12 mx-auto mb-4 opacity-40" />
          <p>No collections yet. Create one to start organizing your data.</p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <.link
            :for={collection <- @collections}
            navigate={~p"/vault/#{collection.id}"}
            class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
          >
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-base">
                  <.icon name="hero-folder" class="size-5" />
                  {collection.name}
                </h2>
                <button
                  class="btn btn-ghost btn-xs"
                  phx-click="delete-collection"
                  phx-value-id={collection.id}
                  data-confirm="Delete this collection and all its items?"
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </div>
              <p :if={collection.description} class="text-sm text-base-content/60">
                {collection.description}
              </p>
            </div>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
