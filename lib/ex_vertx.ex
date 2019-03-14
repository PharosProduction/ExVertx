defmodule ExVertx do

  alias ExVertx.{
    BusSupervisor, 
    BusServer
  }

  # Public

  def start_server(id), do: BusSupervisor.start_child(id)

  def send(id), do: BusServer.send(id)
end
