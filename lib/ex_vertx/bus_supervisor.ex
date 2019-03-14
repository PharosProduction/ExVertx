defmodule ExVertx.BusSupervisor do
  @moduledoc false

  use DynamicSupervisor

  # Public

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_child(id, args \\ nil) do
    spec = {ExVertx.BusServer, [{:id, id} | args]}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  # Callbacks

  @impl true
  def init(args) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 10,
      max_seconds: 5,
      max_children: 100,
      extra_arguments: [args]
    )
  end
end