defmodule ExVertx do
  @moduledoc false

  alias ExVertx.{
    BusServer,
    BusSupervisor
  }

  # Public

  def start_server(id), do: BusSupervisor.start_child(id)

  def send(id), do: BusServer.send(id)
end
