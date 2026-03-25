defmodule SingularityWeb.DashboardLive do
  use SingularityWeb, :live_view

  alias Singularity.{Vault, Agents, Feed}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Singularity.PubSub, "feed:#{user_id}")
    end

    collections = Vault.list_collections(user_id)
    agents = Agents.list_agents(user_id)
    recent_events = Feed.list_events(user_id, limit: 5)

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       collections: collections,
       agents: agents,
       recent_events: recent_events
     )}
  end

  @impl true
  def handle_info({:new_feed_event, _event}, socket) do
    user_id = socket.assigns.current_scope.user.id
    events = Feed.list_events(user_id, limit: 5)
    {:noreply, assign(socket, recent_events: events)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <h1 class="text-2xl font-bold">Dashboard</h1>

        <div class="stats shadow w-full">
          <div class="stat">
            <div class="stat-figure text-primary">
              <.icon name="hero-archive-box" class="size-8" />
            </div>
            <div class="stat-title">Collections</div>
            <div class="stat-value text-primary">{length(@collections)}</div>
          </div>
          <div class="stat">
            <div class="stat-figure text-secondary">
              <.icon name="hero-cpu-chip" class="size-8" />
            </div>
            <div class="stat-title">Agents</div>
            <div class="stat-value text-secondary">{length(@agents)}</div>
          </div>
          <div class="stat">
            <div class="stat-figure text-accent">
              <.icon name="hero-bell" class="size-8" />
            </div>
            <div class="stat-title">Recent Events</div>
            <div class="stat-value text-accent">{length(@recent_events)}</div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Recent activity -->
          <div class="card bg-base-200">
            <div class="card-body">
              <h2 class="card-title">
                <.icon name="hero-bell" class="size-5" /> Recent Activity
              </h2>
              <div :if={@recent_events == []} class="text-base-content/60 py-4">
                No activity yet. Upload some data or create an agent to get started.
              </div>
              <div :for={event <- @recent_events} class="flex gap-3 py-2 border-b border-base-300 last:border-0">
                <div class="badge badge-outline badge-sm mt-1">{event.verb}</div>
                <p class="text-sm">{event.summary || "Event"}</p>
              </div>
            </div>
          </div>

          <!-- Quick actions -->
          <div class="card bg-base-200">
            <div class="card-body">
              <h2 class="card-title">
                <.icon name="hero-bolt" class="size-5" /> Quick Actions
              </h2>
              <div class="flex flex-col gap-2">
                <.link navigate={~p"/vault"} class="btn btn-primary btn-sm justify-start gap-2">
                  <.icon name="hero-plus" class="size-4" /> New Collection
                </.link>
                <.link navigate={~p"/agents"} class="btn btn-secondary btn-sm justify-start gap-2">
                  <.icon name="hero-plus" class="size-4" /> New Agent
                </.link>
                <.link navigate={~p"/shared"} class="btn btn-accent btn-sm justify-start gap-2">
                  <.icon name="hero-share" class="size-4" /> Manage Sharing
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
