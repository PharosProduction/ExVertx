defmodule ExVertx do
  @moduledoc false

  alias ExVertx.{
    BusServer,
    BusSupervisor
  }

  # Public

  @spec start_server(binary, binary, integer) :: {:ok, pid} | {:error, atom}
  def start_server(address, host, port) do
    BusSupervisor.start_child(address, [host: host, port: port])
  end

  @spec send(binary, map, map, binary) :: {:ok, map} | {:error, atom}
  def send(address, body, headers \\ %{}, reply_address \\ "") do
    BusServer.send(address, body, headers, reply_address)
  end

  @spec publish(binary, map, map) :: :ok
  def publish(address, body, headers \\ %{}) do
    BusServer.publish(address, body, headers)
  end
end
