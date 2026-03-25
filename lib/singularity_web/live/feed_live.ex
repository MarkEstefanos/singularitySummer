defmodule SingularityWeb.FeedLive do
  use SingularityWeb, :live_view

  alias Singularity.Feed

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Singularity.PubSub, "feed:#{user_id}")
    end

    events = Feed.list_events(user_id)

    {:ok, assign(socket, page_title: "Feed", events: events)}
  end

  @impl true
  def handle_info({:new_feed_event, _event}, socket) do
    user_id = socket.assigns.current_scope.user.id
    events = Feed.list_events(user_id)
    {:noreply, assign(socket, events: events)}
  end

  defp verb_icon("uploaded"), do: "hero-cloud-arrow-up"
  defp verb_icon("shared"), do: "hero-share"
  defp verb_icon("coordinated"), do: "hero-arrows-right-left"
  defp verb_icon("agent_action"), do: "hero-cpu-chip"
  defp verb_icon("permission_granted"), do: "hero-lock-open"
  defp verb_icon("commented"), do: "hero-chat-bubble-left"
  defp verb_icon(_), do: "hero-bell"

  defp verb_badge("uploaded"), do: "badge-primary"
  defp verb_badge("permission_granted"), do: "badge-accent"
  defp verb_badge("agent_action"), do: "badge-secondary"
  defp verb_badge(_), do: "badge-ghost"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <h1 class="text-2xl font-bold">Feed</h1>

        <div :if={@events == []} class="text-base-content/60 py-12 text-center">
          <.icon name="hero-bell" class="size-12 mx-auto mb-4 opacity-40" />
          <p>No activity yet. Upload data, share collections, or run agents to see events here.</p>
        </div>

        <div class="space-y-2">
          <div :for={event <- @events} class="card bg-base-200">
            <div class="card-body py-3 px-4 flex-row items-center gap-3">
              <div class="flex-none">
                <.icon name={verb_icon(event.verb)} class="size-5 opacity-60" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm">{event.summary || event.verb}</p>
                <p class="text-xs text-base-content/40">
                  {Calendar.strftime(event.inserted_at, "%b %d, %Y at %I:%M %p")}
                </p>
              </div>
              <span class={["badge badge-sm", verb_badge(event.verb)]}>
                {event.verb}
              </span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
