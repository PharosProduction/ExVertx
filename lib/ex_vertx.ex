defmodule ExVertx do
  @moduledoc false

  alias ExVertx.{
    BusServer,
    BusSupervisor
  }

  # Public

  @spec start_server(binary, binary, integer) :: {:ok, pid} | {:error, atom}
  def start_server(address, host, port, timeout \\ :infinity) do
    BusSupervisor.start_child(address, [host: host, port: port, timeout: timeout])
  end

  @spec send(binary, map, map, binary) :: {:ok, map} | {:error, atom}
  def send(address, body, headers \\ %{}, reply_address \\ "") do
    BusServer.send(address, body, headers, reply_address)
  end

  @spec publish(binary, map, map) :: :ok
  def publish(address, body, headers \\ %{}) do
    BusServer.publish(address, body, headers)
  end

  @spec register(binary, map) :: :ok
  def register(address, headers \\ %{}) do
    BusServer.register(address, headers)
  end

  @spec unregister(binary) :: :ok
  def unregister(address) do
    BusServer.unregister(address)
  end

  @spec stop(binary) :: :ok
  def stop(address) do
    BusServer.stop(address)
  end
end
