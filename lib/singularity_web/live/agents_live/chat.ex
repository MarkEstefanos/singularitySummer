defmodule SingularityWeb.AgentsLive.Chat do
  use SingularityWeb, :live_view

  alias Singularity.Agents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    agent = Agents.get_agent!(id)
    user_id = socket.assigns.current_scope.user.id

    if agent.user_id != user_id do
      {:ok, push_navigate(socket, to: ~p"/agents")}
    else
      {:ok,
       assign(socket,
         page_title: "Chat with #{agent.name}",
         agent: agent,
         messages: [],
         input: "",
         loading: false
       )}
    end
  end

  @impl true
  def handle_event("send", %{"message" => message}, socket) when message != "" do
    agent = socket.assigns.agent
    messages = socket.assigns.messages ++ [%{role: "user", content: message}]

    # Start the agent if not running
    Agents.start_agent(agent.id)

    socket = assign(socket, messages: messages, input: "", loading: true)

    # Send message async
    pid = self()
    agent_id = agent.id

    Task.start(fn ->
      case Agents.send_message(agent_id, message) do
        {:ok, response} -> send(pid, {:agent_response, response})
        {:error, reason} -> send(pid, {:agent_error, reason})
      end
    end)

    {:noreply, socket}
  end

  def handle_event("send", _params, socket), do: {:noreply, socket}

  def handle_event("update-input", %{"message" => value}, socket) do
    {:noreply, assign(socket, input: value)}
  end

  @impl true
  def handle_info({:agent_response, response}, socket) do
    messages = socket.assigns.messages ++ [%{role: "assistant", content: response}]
    {:noreply, assign(socket, messages: messages, loading: false)}
  end

  def handle_info({:agent_error, _reason}, socket) do
    {:noreply, socket |> assign(loading: false) |> put_flash(:error, "Agent error")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col h-[calc(100vh-6rem)]">
        <!-- Header -->
        <div class="flex items-center gap-4 pb-4 border-b border-base-300">
          <.link navigate={~p"/agents"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" />
          </.link>
          <div>
            <h1 class="text-lg font-bold flex items-center gap-2">
              <.icon name="hero-cpu-chip" class="size-5" />
              {@agent.name}
            </h1>
            <p :if={@agent.description} class="text-sm text-base-content/60">{@agent.description}</p>
          </div>
        </div>

        <!-- Messages -->
        <div class="flex-1 overflow-y-auto py-4 space-y-4" id="messages" phx-hook="ScrollBottom">
          <div :if={@messages == []} class="text-center text-base-content/40 py-12">
            <.icon name="hero-chat-bubble-left-right" class="size-10 mx-auto mb-2 opacity-40" />
            <p>Start a conversation with {@agent.name}</p>
          </div>

          <div :for={msg <- @messages} class={["chat", msg.role == "user" && "chat-end", msg.role == "assistant" && "chat-start"]}>
            <div class="chat-header text-xs opacity-60">
              {if msg.role == "user", do: "You", else: @agent.name}
            </div>
            <div class={["chat-bubble", msg.role == "user" && "chat-bubble-primary"]}>
              {msg.content}
            </div>
          </div>

          <div :if={@loading} class="chat chat-start">
            <div class="chat-bubble">
              <span class="loading loading-dots loading-sm"></span>
            </div>
          </div>
        </div>

        <!-- Input -->
        <form phx-submit="send" class="flex gap-2 pt-4 border-t border-base-300">
          <input
            type="text"
            name="message"
            value={@input}
            phx-change="update-input"
            class="input input-bordered flex-1"
            placeholder={"Message #{@agent.name}..."}
            autocomplete="off"
            phx-debounce="100"
          />
          <button type="submit" class="btn btn-primary" disabled={@loading}>
            <.icon name="hero-paper-airplane" class="size-5" />
          </button>
        </form>
      </div>
    </Layouts.app>
    """
  end
end
