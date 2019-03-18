defmodule ExVertx.Application do
  @moduledoc false

  use Application

  # Callbacks

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: ExVertx.BusSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ExVertx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
