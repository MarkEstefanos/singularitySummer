defmodule Singularity.Agents do
  @moduledoc """
  Context for managing AI agents and their permissions.
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Agents.{Agent, AgentPermission, Runtime}

  # Agent CRUD

  def list_agents(user_id) do
    Agent
    |> where(user_id: ^user_id)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_agent!(id), do: Repo.get!(Agent, id)

  def create_agent(attrs) do
    %Agent{}
    |> Agent.changeset(attrs)
    |> Repo.insert()
  end

  def update_agent(%Agent{} = agent, attrs) do
    agent
    |> Agent.changeset(attrs)
    |> Repo.update()
  end

  def delete_agent(%Agent{} = agent) do
    Repo.delete(agent)
  end

  # Agent permissions

  def grant_agent_access(attrs) do
    %AgentPermission{}
    |> AgentPermission.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:access_level, :updated_at]},
      conflict_target: [:agent_id, :resource_type, :resource_id]
    )
  end

  def list_agent_permissions(agent_id) do
    AgentPermission
    |> where(agent_id: ^agent_id)
    |> Repo.all()
  end

  # Runtime

  def start_agent(agent_id) do
    agent = get_agent!(agent_id)

    case DynamicSupervisor.start_child(
           Singularity.Agents.Supervisor,
           {Runtime, agent}
         ) do
      {:ok, _pid} ->
        update_agent(agent, %{status: "running"})
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      error ->
        error
    end
  end

  def send_message(agent_id, message) do
    Runtime.send_message(agent_id, message)
  end

  def stop_agent(agent_id) do
    agent = get_agent!(agent_id)
    Runtime.stop(agent_id)
    update_agent(agent, %{status: "inactive"})
    :ok
  rescue
    _ -> :ok
  end
end
