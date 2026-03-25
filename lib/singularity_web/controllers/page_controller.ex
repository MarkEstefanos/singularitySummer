defmodule SingularityWeb.PageController do
  use SingularityWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_scope] do
      redirect(conn, to: ~p"/dashboard")
    else
      redirect(conn, to: ~p"/users/log-in")
    end
  end
end
