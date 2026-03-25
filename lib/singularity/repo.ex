defmodule Singularity.Repo do
  use Ecto.Repo,
    otp_app: :singularity,
    adapter: Ecto.Adapters.Postgres
end
