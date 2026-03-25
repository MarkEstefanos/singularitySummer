defmodule Singularity.Feed do
  @moduledoc """
  Context for the activity feed — append-only event log.
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Feed.Event

  @doc """
  Get feed events visible to a user, most recent first.
  """
  def list_events(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    Event
    |> where([e], ^user_id in e.audience)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Publish a feed event.
  """
  def publish(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, event} -> broadcast(event)
      _ -> :ok
    end)
  end

  defp broadcast(event) do
    for user_id <- event.audience do
      Phoenix.PubSub.broadcast(
        Singularity.PubSub,
        "feed:#{user_id}",
        {:new_feed_event, event}
      )
    end
  end
end
