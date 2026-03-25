defmodule SingularityWeb.AgentsLive.Index do
  use SingularityWeb, :live_view

  alias Singularity.Agents

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    agents = Agents.list_agents(user_id)

    {:ok,
     assign(socket,
       page_title: "Agents",
       agents: agents,
       show_new_form: false
     )}
  end

  @impl true
  def handle_event("toggle-new-form", _params, socket) do
    {:noreply, assign(socket, show_new_form: !socket.assigns.show_new_form)}
  end

  def handle_event("create-agent", params, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Agents.create_agent(%{
           name: params["name"],
           description: params["description"],
           system_prompt: params["system_prompt"],
           user_id: user_id
         }) do
      {:ok, _agent} ->
        agents = Agents.list_agents(user_id)
        {:noreply, socket |> assign(agents: agents, show_new_form: false) |> put_flash(:info, "Agent created")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create agent")}
    end
  end

  def handle_event("delete-agent", %{"id" => id}, socket) do
    agent = Agents.get_agent!(id)
    {:ok, _} = Agents.delete_agent(agent)
    agents = Agents.list_agents(socket.assigns.current_scope.user.id)
    {:noreply, assign(socket, agents: agents) |> put_flash(:info, "Agent deleted")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Agents</h1>
          <button class="btn btn-primary btn-sm" phx-click="toggle-new-form">
            <.icon name="hero-plus" class="size-4" /> New Agent
          </button>
        </div>

        <!-- New agent form -->
        <div :if={@show_new_form} class="card bg-base-200">
          <div class="card-body">
            <form phx-submit="create-agent" class="flex flex-col gap-3">
              <div class="form-control">
                <label class="label"><span class="label-text">Name</span></label>
                <input
                  type="text"
                  name="name"
                  class="input input-bordered"
                  placeholder="e.g. Personal Assistant, Calendar Bot"
                  required
                  phx-mounted={JS.focus()}
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Description</span></label>
                <input
                  type="text"
                  name="description"
                  class="input input-bordered"
                  placeholder="What does this agent do?"
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">System Prompt</span></label>
                <textarea
                  name="system_prompt"
                  class="textarea textarea-bordered h-24"
                  placeholder="You are a helpful assistant that..."
                ></textarea>
              </div>
              <div class="flex gap-2">
                <button type="submit" class="btn btn-primary btn-sm">Create</button>
                <button type="button" class="btn btn-ghost btn-sm" phx-click="toggle-new-form">Cancel</button>
              </div>
            </form>
          </div>
        </div>

        <!-- Agents list -->
        <div :if={@agents == []} class="text-base-content/60 py-12 text-center">
          <.icon name="hero-cpu-chip" class="size-12 mx-auto mb-4 opacity-40" />
          <p>No agents yet. Create one to get started.</p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div :for={agent <- @agents} class="card bg-base-200">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-base">
                  <.icon name="hero-cpu-chip" class="size-5" />
                  {agent.name}
                </h2>
                <div class="flex items-center gap-1">
                  <span class={[
                    "badge badge-sm",
                    agent.status == "running" && "badge-success",
                    agent.status == "active" && "badge-info",
                    agent.status == "inactive" && "badge-ghost",
                    agent.status == "error" && "badge-error"
                  ]}>
                    {agent.status}
                  </span>
                  <button
                    class="btn btn-ghost btn-xs"
                    phx-click="delete-agent"
                    phx-value-id={agent.id}
                    data-confirm="Delete this agent?"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              </div>
              <p :if={agent.description} class="text-sm text-base-content/60">{agent.description}</p>
              <div class="card-actions justify-end mt-2">
                <.link navigate={~p"/agents/#{agent.id}"} class="btn btn-sm btn-outline">
                  <.icon name="hero-chat-bubble-left-right" class="size-4" /> Chat
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
