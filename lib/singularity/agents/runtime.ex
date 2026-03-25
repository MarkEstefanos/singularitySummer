defmodule Singularity.Agents.Runtime do
  @moduledoc """
  GenServer that runs an agent instance. Each running agent is a supervised process
  that can receive messages, access vault data within its permissions, and coordinate
  with other agents.
  """

  use GenServer
  require Logger

  defstruct [:agent, :user_id, :messages, :tools]

  # Client API

  def start_link(agent) do
    GenServer.start_link(__MODULE__, agent, name: via(agent.id))
  end

  def send_message(agent_id, message) do
    GenServer.call(via(agent_id), {:message, message}, 30_000)
  end

  def stop(agent_id) do
    GenServer.stop(via(agent_id))
  end

  defp via(agent_id) do
    {:via, Registry, {Singularity.Agents.Registry, agent_id}}
  end

  # Server callbacks

  @impl true
  def init(agent) do
    state = %__MODULE__{
      agent: agent,
      user_id: agent.user_id,
      messages: [],
      tools: build_tools(agent)
    }

    Logger.info("Agent #{agent.name} (#{agent.id}) started for user #{agent.user_id}")
    {:ok, state}
  end

  @impl true
  def handle_call({:message, message}, _from, state) do
    state = %{state | messages: state.messages ++ [%{role: "user", content: message}]}

    # TODO: Call AI API with system_prompt, messages, and tools
    # For now, echo back
    response = "Agent #{state.agent.name} received: #{message}"
    state = %{state | messages: state.messages ++ [%{role: "assistant", content: response}]}

    {:reply, {:ok, response}, state}
  end

  defp build_tools(_agent) do
    # TODO: Build tool definitions based on agent's permissions
    # e.g., read_collection, search_items, write_item, message_agent
    []
  end
end
