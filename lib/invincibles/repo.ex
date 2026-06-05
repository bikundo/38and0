defmodule Invincibles.Repo do
  use Ecto.Repo,
    otp_app: :invincibles,
    adapter: Ecto.Adapters.Postgres
end
