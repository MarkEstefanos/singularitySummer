defmodule SingularityWeb.SharedLive do
  use SingularityWeb, :live_view

  alias Singularity.{Permissions, Vault}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    shared_with_me = Permissions.list_shared_with(user_id)
    my_grants = Permissions.list_grants_by(user_id)

    # Resolve resource names
    shared_with_me = Enum.map(shared_with_me, &resolve_resource/1)
    my_grants = Enum.map(my_grants, &resolve_resource/1)

    {:ok,
     assign(socket,
       page_title: "Shared with Me",
       shared_with_me: shared_with_me,
       my_grants: my_grants,
       active_tab: "received"
     )}
  end

  @impl true
  def handle_event("switch-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    alias Singularity.Repo
    perm = Repo.get!(Permissions.Permission, id)
    Repo.delete!(perm)

    user_id = socket.assigns.current_scope.user.id
    my_grants = Permissions.list_grants_by(user_id) |> Enum.map(&resolve_resource/1)
    {:noreply, assign(socket, my_grants: my_grants) |> put_flash(:info, "Access revoked")}
  end

  defp resolve_resource(permission) do
    resource_name =
      case permission.resource_type do
        "collection" ->
          try do
            Vault.get_collection!(permission.resource_id).name
          rescue
            _ -> "Unknown collection"
          end

        "item" ->
          try do
            Vault.get_item!(permission.resource_id).name
          rescue
            _ -> "Unknown item"
          end
      end

    Map.put(permission, :resource_name, resource_name)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <h1 class="text-2xl font-bold">Sharing</h1>

        <!-- Tabs -->
        <div role="tablist" class="tabs tabs-bordered">
          <button
            role="tab"
            class={["tab", @active_tab == "received" && "tab-active"]}
            phx-click="switch-tab"
            phx-value-tab="received"
          >
            Shared with Me
          </button>
          <button
            role="tab"
            class={["tab", @active_tab == "granted" && "tab-active"]}
            phx-click="switch-tab"
            phx-value-tab="granted"
          >
            My Shares
          </button>
        </div>

        <!-- Shared with me -->
        <div :if={@active_tab == "received"}>
          <div :if={@shared_with_me == []} class="text-base-content/60 py-8 text-center">
            <p>Nothing shared with you yet.</p>
          </div>

          <div class="space-y-2">
            <div :for={perm <- @shared_with_me} class="card bg-base-200">
              <div class="card-body py-3 px-4 flex-row items-center gap-3">
                <.icon name="hero-folder" class="size-5 opacity-60" />
                <div class="flex-1">
                  <p class="font-medium text-sm">{perm.resource_name}</p>
                  <p class="text-xs text-base-content/40">
                    from {perm.grantor.email}
                  </p>
                </div>
                <span class="badge badge-sm badge-outline">{perm.access_level}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- My shares -->
        <div :if={@active_tab == "granted"}>
          <div :if={@my_grants == []} class="text-base-content/60 py-8 text-center">
            <p>You haven't shared anything yet. Share from the Vault.</p>
          </div>

          <div class="space-y-2">
            <div :for={perm <- @my_grants} class="card bg-base-200">
              <div class="card-body py-3 px-4 flex-row items-center gap-3">
                <.icon name="hero-folder" class="size-5 opacity-60" />
                <div class="flex-1">
                  <p class="font-medium text-sm">{perm.resource_name}</p>
                  <p class="text-xs text-base-content/40">
                    shared with {perm.grantee.email}
                  </p>
                </div>
                <span class="badge badge-sm badge-outline">{perm.access_level}</span>
                <button
                  class="btn btn-ghost btn-xs"
                  phx-click="revoke"
                  phx-value-id={perm.id}
                  data-confirm="Revoke access?"
                >
                  <.icon name="hero-x-mark" class="size-4" />
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
