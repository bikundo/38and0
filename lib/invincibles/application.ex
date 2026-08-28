defmodule Invincibles.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      InvinciblesWeb.Telemetry,
      Invincibles.Repo,
      {DNSCluster, query: Application.get_env(:invincibles, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Invincibles.PubSub},
      InvinciblesWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Invincibles.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    InvinciblesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
