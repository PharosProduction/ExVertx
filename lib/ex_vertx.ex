defmodule ExVertx do
  @moduledoc false

  alias ExVertx.{
    BusServer,
    BusSupervisor
  }

  # Public

  @spec start_server(pid, binary, binary, integer, integer | :infinity) :: {:ok, pid} | {:error, atom}
  def start_server(from, address, host, port, timeout \\ :infinity) do
    [from: from, address: address, host: host, port: port, timeout: timeout]
    |> BusSupervisor.start_child
  end

  @spec send(binary, map, map, binary) :: {:ok, map} | {:error, atom}
  def send(address, body, headers \\ %{}, reply_address \\ "") do
    [address: address, body: body, headers: headers, reply_address: reply_address]
    |> BusServer.send
  end

  @spec publish(binary, map, map) :: :ok | {:error, atom}
  def publish(address, body, headers \\ %{}) do
    [address: address, body: body, headers: headers]
    |> BusServer.publish
  end

  @spec register(binary, map) :: :ok | {:error, atom}
  def register(address, headers \\ %{}) do
    [address: address, headers: headers]
    |> BusServer.register
  end

  @spec unregister(binary) :: :ok | {:error, atom}
  def unregister(address) do
    [address: address]
    |> BusServer.unregister
  end

  @spec stop(binary) :: :ok | {:error, atom}
  def stop(address) do
    [address: address]
    |> BusServer.stop
  end
end
