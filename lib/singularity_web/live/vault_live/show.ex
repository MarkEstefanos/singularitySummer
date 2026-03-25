defmodule SingularityWeb.VaultLive.Show do
  @moduledoc """
  Deprecated — vault now uses a flat file browser at /vault.
  This module redirects old collection URLs to the main vault index.
  """
  use SingularityWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/vault")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <p>Redirecting...</p>
    </Layouts.app>
    """
  end
end
