defmodule SingularityWeb.CirclesLive.Index do
  use SingularityWeb, :live_view

  alias Singularity.{Circles, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    circles = Circles.list_circles(user_id)
    memberships = Circles.list_memberships(user_id)

    {:ok,
     assign(socket,
       page_title: "Circles",
       circles: circles,
       memberships: memberships,
       show_new_form: false,
       editing_circle: nil,
       add_member_email: ""
     )}
  end

  @impl true
  def handle_event("toggle-new-form", _params, socket) do
    {:noreply, assign(socket, show_new_form: !socket.assigns.show_new_form)}
  end

  def handle_event("create-circle", %{"name" => name, "description" => desc, "color" => color}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Circles.create_circle(%{name: name, description: desc, color: color, user_id: user_id}) do
      {:ok, _} ->
        circles = Circles.list_circles(user_id)
        {:noreply, socket |> assign(circles: circles, show_new_form: false) |> put_flash(:info, "Circle created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create circle")}
    end
  end

  def handle_event("delete-circle", %{"id" => id}, socket) do
    circle = Circles.get_circle!(id)
    {:ok, _} = Circles.delete_circle(circle)
    circles = Circles.list_circles(socket.assigns.current_scope.user.id)
    {:noreply, assign(socket, circles: circles) |> put_flash(:info, "Circle deleted")}
  end

  def handle_event("toggle-manage", %{"id" => id}, socket) do
    if socket.assigns.editing_circle && socket.assigns.editing_circle.id == String.to_integer(id) do
      {:noreply, assign(socket, editing_circle: nil)}
    else
      circle = Circles.get_circle!(id)
      {:noreply, assign(socket, editing_circle: circle)}
    end
  end

  def handle_event("add-member", %{"email" => email}, socket) do
    circle = socket.assigns.editing_circle

    case Accounts.get_user_by_email(email) do
      nil ->
        {:noreply, put_flash(socket, :error, "User not found")}

      user ->
        case Circles.add_member(circle.id, user.id) do
          {:ok, _} ->
            circle = Circles.get_circle!(circle.id)
            circles = Circles.list_circles(socket.assigns.current_scope.user.id)
            {:noreply, socket |> assign(editing_circle: circle, circles: circles) |> put_flash(:info, "Added #{email}")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Already in this circle")}
        end
    end
  end

  def handle_event("remove-member", %{"circle-id" => circle_id, "user-id" => user_id}, socket) do
    Circles.remove_member(circle_id, user_id)
    circle = Circles.get_circle!(circle_id)
    circles = Circles.list_circles(socket.assigns.current_scope.user.id)
    {:noreply, assign(socket, editing_circle: circle, circles: circles)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Circles</h1>
          <button class="btn btn-primary btn-sm" phx-click="toggle-new-form">
            <.icon name="hero-plus" class="size-4" /> New Circle
          </button>
        </div>

        <!-- New circle form -->
        <div :if={@show_new_form} class="card bg-base-200">
          <div class="card-body">
            <form phx-submit="create-circle" class="flex flex-col gap-3">
              <div class="form-control">
                <label class="label"><span class="label-text">Name</span></label>
                <input type="text" name="name" class="input input-bordered" placeholder="e.g. Close Friends, Family, Work" required phx-mounted={JS.focus()} />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Description</span></label>
                <input type="text" name="description" class="input input-bordered" placeholder="Optional description" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Color</span></label>
                <input type="color" name="color" value="#6366f1" class="w-12 h-10 cursor-pointer" />
              </div>
              <div class="flex gap-2">
                <button type="submit" class="btn btn-primary btn-sm">Create</button>
                <button type="button" class="btn btn-ghost btn-sm" phx-click="toggle-new-form">Cancel</button>
              </div>
            </form>
          </div>
        </div>

        <!-- My circles -->
        <div :if={@circles == [] && @memberships == []} class="text-base-content/60 py-12 text-center">
          <.icon name="hero-user-group" class="size-12 mx-auto mb-4 opacity-40" />
          <p>No circles yet. Create one and add friends to start sharing.</p>
        </div>

        <div :if={@circles != []} class="space-y-3">
          <h2 class="text-lg font-semibold">My Circles</h2>
          <div :for={circle <- @circles} class="card bg-base-200">
            <div class="card-body py-4">
              <div class="flex items-center gap-3">
                <div class="w-4 h-4 rounded-full" style={"background-color: #{circle.color}"}></div>
                <div class="flex-1">
                  <h3 class="font-semibold">{circle.name}</h3>
                  <p :if={circle.description} class="text-sm text-base-content/60">{circle.description}</p>
                </div>
                <div class="flex items-center gap-1">
                  <div class="avatar-group -space-x-3">
                    <div :for={member <- Enum.take(circle.members, 3)} class="avatar placeholder">
                      <div class="bg-neutral text-neutral-content rounded-full w-8">
                        <span class="text-xs">{String.first(member.email) |> String.upcase()}</span>
                      </div>
                    </div>
                    <div :if={length(circle.members) > 3} class="avatar placeholder">
                      <div class="bg-neutral text-neutral-content rounded-full w-8">
                        <span class="text-xs">+{length(circle.members) - 3}</span>
                      </div>
                    </div>
                  </div>
                  <span class="badge badge-sm badge-ghost">{length(circle.members)} members</span>
                  <button class="btn btn-ghost btn-xs" phx-click="toggle-manage" phx-value-id={circle.id}>
                    <.icon name="hero-cog-6-tooth" class="size-4" />
                  </button>
                  <button class="btn btn-ghost btn-xs" phx-click="delete-circle" phx-value-id={circle.id} data-confirm="Delete this circle?">
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              </div>

              <!-- Manage members panel -->
              <div :if={@editing_circle && @editing_circle.id == circle.id} class="mt-4 pt-4 border-t border-base-300">
                <form phx-submit="add-member" class="flex gap-2 mb-3">
                  <input type="email" name="email" class="input input-bordered input-sm flex-1" placeholder="Add member by email" required />
                  <button type="submit" class="btn btn-primary btn-sm">Add</button>
                </form>
                <div :if={@editing_circle.members == []} class="text-sm text-base-content/60">
                  No members yet.
                </div>
                <div :for={member <- @editing_circle.members} class="flex items-center gap-2 py-1">
                  <div class="avatar placeholder">
                    <div class="bg-neutral text-neutral-content rounded-full w-6">
                      <span class="text-xs">{String.first(member.email) |> String.upcase()}</span>
                    </div>
                  </div>
                  <span class="text-sm flex-1">{member.email}</span>
                  <button class="btn btn-ghost btn-xs" phx-click="remove-member" phx-value-circle-id={circle.id} phx-value-user-id={member.id}>
                    <.icon name="hero-x-mark" class="size-3" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Circles I'm a member of -->
        <div :if={@memberships != []} class="space-y-3">
          <h2 class="text-lg font-semibold">Member of</h2>
          <div :for={circle <- @memberships} class="card bg-base-200">
            <div class="card-body py-3 flex-row items-center gap-3">
              <div class="w-4 h-4 rounded-full" style={"background-color: #{circle.color}"}></div>
              <div class="flex-1">
                <span class="font-medium">{circle.name}</span>
                <span class="text-sm text-base-content/60 ml-2">by {circle.user.email}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
