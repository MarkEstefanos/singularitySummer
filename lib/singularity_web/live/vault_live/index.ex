defmodule SingularityWeb.VaultLive.Index do
  use SingularityWeb, :live_view

  alias Singularity.{Vault, Ingestion, Feed, Circles}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    {:ok,
     socket
     |> assign(
       page_title: "Vault",
       current_folder: nil,
       show_new_folder: false,
       new_folder_name: "",
       sharing_item_id: nil
     )
     |> load_data(user_id)
     |> allow_upload(:file,
       accept: :any,
       max_entries: 10,
       max_file_size: 100_000_000
     )}
  end

  defp load_data(socket, user_id) do
    current_folder = socket.assigns[:current_folder]
    items = Vault.list_items_for_user(user_id, folder_path: current_folder, all_folders: current_folder == nil)
    folders = Vault.list_folders(user_id)
    circles = Circles.list_circles(user_id)

    # When viewing root, separate folders from files
    {folder_items, root_items} =
      if current_folder == nil do
        # Show all items but group: folders first, then unfiled items
        unfiled = Enum.filter(items, &is_nil(&1.folder_path))
        {folders, unfiled}
      else
        {[], items}
      end

    assign(socket,
      items: root_items,
      folders: folder_items,
      circles: circles,
      item_shares: load_item_shares(root_items)
    )
  end

  defp load_item_shares(items) do
    Map.new(items, fn item ->
      {item.id, Circles.list_shares_for_resource("item", item.id)}
    end)
  end

  @impl true
  def handle_params(%{"folder" => folder}, _uri, socket) do
    user_id = socket.assigns.current_scope.user.id

    {:noreply,
     socket
     |> assign(current_folder: folder, page_title: "Vault - #{Path.basename(folder)}")
     |> load_data(user_id)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload", _params, socket) do
    user_id = socket.assigns.current_scope.user.id
    current_folder = socket.assigns.current_folder

    uploaded_items =
      consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
        result =
          Ingestion.ingest(%{
            path: path,
            name: entry.client_name,
            content_type: entry.client_type,
            user_id: user_id,
            folder_path: current_folder
          })

        case result do
          {:ok, item} ->
            Feed.publish(%{
              verb: "uploaded",
              summary: "Uploaded #{entry.client_name}",
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

    count = length(uploaded_items)

    {:noreply,
     socket
     |> load_data(user_id)
     |> put_flash(:info, "#{count} file(s) uploaded")}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file, ref)}
  end

  def handle_event("delete-item", %{"id" => id}, socket) do
    item = Vault.get_item!(id)
    {:ok, _} = Vault.delete_item(item)
    user_id = socket.assigns.current_scope.user.id

    {:noreply,
     socket
     |> load_data(user_id)
     |> put_flash(:info, "File deleted")}
  end

  def handle_event("toggle-new-folder", _params, socket) do
    {:noreply, assign(socket, show_new_folder: !socket.assigns.show_new_folder)}
  end

  def handle_event("create-folder", %{"name" => name}, socket) do
    # Folders are virtual — just a path prefix. Create a placeholder that
    # will show up once a file is placed in it. For now, navigate to it.
    folder_path =
      case socket.assigns.current_folder do
        nil -> "/" <> name
        parent -> parent <> "/" <> name
      end

    {:noreply,
     socket
     |> assign(show_new_folder: false)
     |> push_patch(to: ~p"/vault?#{%{folder: folder_path}}")}
  end

  def handle_event("navigate-folder", %{"path" => path}, socket) do
    {:noreply, push_patch(socket, to: ~p"/vault?#{%{folder: path}}")}
  end

  def handle_event("navigate-root", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/vault")}
  end

  def handle_event("open-share", %{"id" => id}, socket) do
    {:noreply, assign(socket, sharing_item_id: String.to_integer(id))}
  end

  def handle_event("close-share", _params, socket) do
    {:noreply, assign(socket, sharing_item_id: nil)}
  end

  def handle_event("share-item", %{"circle_id" => circle_id, "access_level" => level}, socket) do
    item_id = socket.assigns.sharing_item_id
    user_id = socket.assigns.current_scope.user.id

    case Circles.share_with_circle(%{
           circle_id: circle_id,
           resource_type: "item",
           resource_id: item_id,
           access_level: level
         }) do
      {:ok, _} ->
        circle = Circles.get_circle!(circle_id)
        item = Vault.get_item!(item_id)
        member_ids = Enum.map(circle.members, & &1.id)

        Feed.publish(%{
          verb: "shared",
          summary: "Shared #{item.name} with circle #{circle.name} (#{level})",
          actor_type: "user",
          actor_id: user_id,
          object_type: "item",
          object_id: item_id,
          audience: [user_id | member_ids]
        })

        {:noreply,
         socket
         |> load_data(user_id)
         |> assign(sharing_item_id: nil)
         |> put_flash(:info, "Shared with #{circle.name}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to share")}
    end
  end

  def handle_event("unshare-item", %{"circle-id" => circle_id, "item-id" => item_id}, socket) do
    user_id = socket.assigns.current_scope.user.id
    Circles.unshare_with_circle(circle_id, "item", String.to_integer(item_id))

    {:noreply,
     socket
     |> load_data(user_id)
     |> put_flash(:info, "Access removed")}
  end

  defp format_size(nil), do: "-"
  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp file_icon(content_type) do
    cond do
      String.starts_with?(content_type || "", "image/") -> "hero-photo"
      String.starts_with?(content_type || "", "video/") -> "hero-film"
      String.starts_with?(content_type || "", "audio/") -> "hero-musical-note"
      content_type in ["application/pdf"] -> "hero-document-text"
      true -> "hero-document"
    end
  end

  defp breadcrumbs(nil), do: []

  defp breadcrumbs(path) do
    parts = path |> String.trim_leading("/") |> String.split("/")

    parts
    |> Enum.with_index()
    |> Enum.map(fn {part, idx} ->
      full_path = "/" <> Enum.join(Enum.take(parts, idx + 1), "/")
      {part, full_path}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-4">
        <!-- Header -->
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <h1 class="text-2xl font-bold">Vault</h1>
            <!-- Breadcrumbs -->
            <div :if={@current_folder} class="breadcrumbs text-sm ml-2">
              <ul>
                <li>
                  <button phx-click="navigate-root" class="link link-hover">All Files</button>
                </li>
                <li :for={{name, path} <- breadcrumbs(@current_folder)}>
                  <button phx-click="navigate-folder" phx-value-path={path} class="link link-hover">
                    {name}
                  </button>
                </li>
              </ul>
            </div>
          </div>
          <button class="btn btn-ghost btn-sm" phx-click="toggle-new-folder">
            <.icon name="hero-folder-plus" class="size-4" /> New Folder
          </button>
        </div>

        <!-- New folder form -->
        <div :if={@show_new_folder} class="card bg-base-200">
          <div class="card-body py-3">
            <form phx-submit="create-folder" class="flex items-end gap-3">
              <div class="form-control flex-1">
                <label class="label"><span class="label-text">Folder name</span></label>
                <input
                  type="text"
                  name="name"
                  class="input input-bordered input-sm"
                  placeholder="e.g. Photos, Documents"
                  required
                  phx-mounted={JS.focus()}
                />
              </div>
              <button type="submit" class="btn btn-primary btn-sm">Create</button>
              <button type="button" class="btn btn-ghost btn-sm" phx-click="toggle-new-folder">
                Cancel
              </button>
            </form>
          </div>
        </div>

        <!-- Upload area -->
        <div class="card bg-base-200">
          <div class="card-body py-4">
            <form id="upload-form" phx-submit="upload" phx-change="validate-upload">
              <div
                class="border-2 border-dashed border-base-300 rounded-lg p-6 text-center hover:border-primary transition-colors"
                phx-drop-target={@uploads.file.ref}
              >
                <.icon name="hero-cloud-arrow-up" class="size-8 mx-auto mb-2 opacity-40" />
                <p class="text-sm text-base-content/60 mb-2">
                  Drag & drop files here, or click to browse
                </p>
                <.live_file_input upload={@uploads.file} class="file-input file-input-bordered file-input-sm" />
              </div>

              <!-- Pending uploads -->
              <div :for={entry <- @uploads.file.entries} class="flex items-center gap-3 mt-3">
                <span class="text-sm flex-1 truncate">{entry.client_name}</span>
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

        <!-- Folders -->
        <div :if={@current_folder == nil && @folders != []} class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
          <button
            :for={folder <- @folders}
            phx-click="navigate-folder"
            phx-value-path={folder}
            class="flex items-center gap-2 p-3 rounded-lg bg-base-200 hover:bg-base-300 transition-colors text-left"
          >
            <.icon name="hero-folder" class="size-5 text-warning" />
            <span class="text-sm font-medium truncate">{Path.basename(folder)}</span>
          </button>
        </div>

        <!-- Items table -->
        <div :if={@items == [] && @folders == []} class="text-base-content/60 py-12 text-center">
          <.icon name="hero-cloud-arrow-up" class="size-12 mx-auto mb-4 opacity-40" />
          <p>No files yet. Drag & drop files above to get started.</p>
        </div>

        <div :if={@items == [] && @current_folder != nil} class="text-base-content/60 py-8 text-center">
          <p>This folder is empty. Upload files above.</p>
        </div>

        <div class="overflow-x-auto" :if={@items != []}>
          <table class="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Size</th>
                <th>Date</th>
                <th>Shared</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={item <- @items} class="hover">
                <td>
                  <div class="flex items-center gap-2">
                    <.icon name={file_icon(item.content_type)} class="size-4 opacity-60 shrink-0" />
                    <span class="truncate max-w-xs">{item.name}</span>
                    <span
                      :if={item.folder_path && @current_folder == nil}
                      class="badge badge-xs badge-ghost"
                    >
                      {Path.basename(item.folder_path)}
                    </span>
                  </div>
                </td>
                <td>
                  <span class="badge badge-sm badge-outline">{item.content_type}</span>
                </td>
                <td class="text-sm whitespace-nowrap">{format_size(item.size_bytes)}</td>
                <td class="text-sm text-base-content/60 whitespace-nowrap">
                  {Calendar.strftime(item.inserted_at, "%b %d, %Y")}
                </td>
                <td>
                  <div class="flex items-center gap-1">
                    <div
                      :for={share <- Map.get(@item_shares, item.id, [])}
                      class="tooltip"
                      data-tip={"#{share.circle.name} (#{share.access_level})"}
                    >
                      <div
                        class="w-3 h-3 rounded-full"
                        style={"background-color: #{share.circle.color}"}
                      >
                      </div>
                    </div>
                  </div>
                </td>
                <td>
                  <div class="flex items-center gap-1">
                    <button
                      class="btn btn-ghost btn-xs"
                      phx-click="open-share"
                      phx-value-id={item.id}
                      title="Share"
                    >
                      <.icon name="hero-share" class="size-4" />
                    </button>
                    <button
                      class="btn btn-ghost btn-xs"
                      phx-click="delete-item"
                      phx-value-id={item.id}
                      data-confirm="Delete this file?"
                    >
                      <.icon name="hero-trash" class="size-4" />
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Inline share panel -->
        <div :if={@sharing_item_id} class="card bg-base-200 border border-primary/20">
          <div class="card-body py-4 space-y-3">
            <div class="flex items-center justify-between">
              <h3 class="font-semibold text-sm">
                Share file
              </h3>
              <button class="btn btn-ghost btn-xs" phx-click="close-share">
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
            <div :if={@circles == []} class="text-sm text-base-content/60">
              No circles yet.
              <.link navigate={~p"/circles"} class="link link-primary">Create one first</.link>.
            </div>
            <form :if={@circles != []} phx-submit="share-item" class="flex gap-2 items-end">
              <div class="form-control flex-1">
                <select name="circle_id" class="select select-bordered select-sm">
                  <option :for={circle <- @circles} value={circle.id}>
                    {circle.name} ({length(circle.members)} members)
                  </option>
                </select>
              </div>
              <div class="form-control">
                <select name="access_level" class="select select-bordered select-sm">
                  <option value="metadata">Metadata only</option>
                  <option value="read" selected>Read</option>
                  <option value="write">Write</option>
                </select>
              </div>
              <button type="submit" class="btn btn-primary btn-sm">Share</button>
            </form>

            <!-- Current shares for this item -->
            <div
              :if={Map.get(@item_shares, @sharing_item_id, []) != []}
              class="pt-2 border-t border-base-300"
            >
              <p class="text-xs font-medium mb-1 text-base-content/60">Currently shared with:</p>
              <div
                :for={share <- Map.get(@item_shares, @sharing_item_id, [])}
                class="flex items-center gap-2 py-1"
              >
                <div
                  class="w-3 h-3 rounded-full"
                  style={"background-color: #{share.circle.color}"}
                >
                </div>
                <span class="text-sm flex-1">{share.circle.name}</span>
                <span class="badge badge-sm badge-outline">{share.access_level}</span>
                <button
                  class="btn btn-ghost btn-xs"
                  phx-click="unshare-item"
                  phx-value-circle-id={share.circle.id}
                  phx-value-item-id={@sharing_item_id}
                >
                  <.icon name="hero-x-mark" class="size-3" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
