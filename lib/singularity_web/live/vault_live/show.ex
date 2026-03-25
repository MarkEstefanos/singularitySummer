defmodule SingularityWeb.VaultLive.Show do
  use SingularityWeb, :live_view

  alias Singularity.{Vault, Ingestion, Feed}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    collection = Vault.get_collection!(id)
    user_id = socket.assigns.current_scope.user.id

    # Verify ownership
    if collection.user_id != user_id do
      {:ok, push_navigate(socket, to: ~p"/vault")}
    else
      items = Vault.list_items(collection.id)

      {:ok,
       socket
       |> assign(
         page_title: collection.name,
         collection: collection,
         items: items,
         show_share_modal: false,
         share_email: ""
       )
       |> allow_upload(:file,
         accept: :any,
         max_entries: 10,
         max_file_size: 100_000_000
       )}
    end
  end

  @impl true
  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload", _params, socket) do
    user_id = socket.assigns.current_scope.user.id
    collection = socket.assigns.collection

    uploaded_items =
      consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
        result =
          Ingestion.ingest(%{
            path: path,
            name: entry.client_name,
            content_type: entry.client_type,
            collection_id: collection.id,
            user_id: user_id
          })

        case result do
          {:ok, item} ->
            Feed.publish(%{
              verb: "uploaded",
              summary: "Uploaded #{entry.client_name} to #{collection.name}",
              actor_type: "user",
              actor_id: user_id,
              object_type: "item",
              object_id: item.id,
              audience: [user_id]
            })

            {:ok, item}

          {:error, reason} ->
            {:postpone, reason}
        end
      end)

    items = Vault.list_items(collection.id)
    count = length(uploaded_items)

    {:noreply,
     socket
     |> assign(items: items)
     |> put_flash(:info, "#{count} file(s) uploaded")}
  end

  def handle_event("delete-item", %{"id" => id}, socket) do
    item = Vault.get_item!(id)
    {:ok, _} = Vault.delete_item(item)
    items = Vault.list_items(socket.assigns.collection.id)
    {:noreply, assign(socket, items: items) |> put_flash(:info, "Item deleted")}
  end

  def handle_event("toggle-share-modal", _params, socket) do
    {:noreply, assign(socket, show_share_modal: !socket.assigns.show_share_modal)}
  end

  def handle_event("share-collection", %{"email" => email, "access_level" => level}, socket) do
    alias Singularity.{Accounts, Permissions}
    user_id = socket.assigns.current_scope.user.id
    collection = socket.assigns.collection

    case Accounts.get_user_by_email(email) do
      nil ->
        {:noreply, put_flash(socket, :error, "User not found")}

      grantee ->
        case Permissions.grant_access(%{
               grantor_id: user_id,
               grantee_id: grantee.id,
               resource_type: "collection",
               resource_id: collection.id,
               access_level: level
             }) do
          {:ok, _} ->
            Feed.publish(%{
              verb: "permission_granted",
              summary: "Shared #{collection.name} with #{email} (#{level})",
              actor_type: "user",
              actor_id: user_id,
              object_type: "collection",
              object_id: collection.id,
              audience: [user_id, grantee.id]
            })

            {:noreply,
             socket
             |> assign(show_share_modal: false)
             |> put_flash(:info, "Shared with #{email}")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to share")}
        end
    end
  end

  defp format_size(nil), do: "-"
  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <!-- Header -->
        <div class="flex items-center gap-4">
          <.link navigate={~p"/vault"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" />
          </.link>
          <div class="flex-1">
            <h1 class="text-2xl font-bold">{@collection.name}</h1>
            <p :if={@collection.description} class="text-sm text-base-content/60">
              {@collection.description}
            </p>
          </div>
          <button class="btn btn-outline btn-sm" phx-click="toggle-share-modal">
            <.icon name="hero-share" class="size-4" /> Share
          </button>
        </div>

        <!-- Share modal -->
        <div :if={@show_share_modal} class="card bg-base-200">
          <div class="card-body">
            <h3 class="font-semibold">Share this collection</h3>
            <form phx-submit="share-collection" class="flex gap-2 items-end">
              <div class="form-control flex-1">
                <label class="label"><span class="label-text">User email</span></label>
                <input type="email" name="email" class="input input-bordered input-sm" required />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Access</span></label>
                <select name="access_level" class="select select-bordered select-sm">
                  <option value="metadata">Metadata only</option>
                  <option value="read" selected>Read</option>
                  <option value="write">Write</option>
                </select>
              </div>
              <button type="submit" class="btn btn-primary btn-sm">Share</button>
              <button type="button" class="btn btn-ghost btn-sm" phx-click="toggle-share-modal">Cancel</button>
            </form>
          </div>
        </div>

        <!-- Upload area -->
        <div class="card bg-base-200">
          <div class="card-body">
            <form id="upload-form" phx-submit="upload" phx-change="validate-upload">
              <div
                class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors"
                phx-drop-target={@uploads.file.ref}
              >
                <.icon name="hero-cloud-arrow-up" class="size-10 mx-auto mb-2 opacity-40" />
                <p class="text-sm text-base-content/60 mb-2">
                  Drag & drop files here, or click to browse
                </p>
                <.live_file_input upload={@uploads.file} class="file-input file-input-bordered file-input-sm" />
              </div>

              <!-- Pending uploads -->
              <div :for={entry <- @uploads.file.entries} class="flex items-center gap-3 mt-3">
                <span class="text-sm flex-1">{entry.client_name}</span>
                <progress class="progress progress-primary w-24" value={entry.progress} max="100" />
                <button
                  type="button"
                  class="btn btn-ghost btn-xs"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  aria-label="cancel"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>

              <button
                :if={@uploads.file.entries != []}
                type="submit"
                class="btn btn-primary btn-sm mt-3"
              >
                Upload {length(@uploads.file.entries)} file(s)
              </button>
            </form>
          </div>
        </div>

        <!-- Items list -->
        <div :if={@items == []} class="text-base-content/60 py-8 text-center">
          <p>No items yet. Upload some files above.</p>
        </div>

        <div class="overflow-x-auto" :if={@items != []}>
          <table class="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Size</th>
                <th>Uploaded</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={item <- @items} class="hover">
                <td class="flex items-center gap-2">
                  <.icon name="hero-document" class="size-4 opacity-60" />
                  {item.name}
                </td>
                <td>
                  <span class="badge badge-sm badge-outline">{item.content_type}</span>
                </td>
                <td class="text-sm">{format_size(item.size_bytes)}</td>
                <td class="text-sm text-base-content/60">
                  {Calendar.strftime(item.inserted_at, "%b %d, %Y")}
                </td>
                <td>
                  <button
                    class="btn btn-ghost btn-xs"
                    phx-click="delete-item"
                    phx-value-id={item.id}
                    data-confirm="Delete this item?"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
