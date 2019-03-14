defmodule ExVertx.BusService do

  # Attributes

  @timeout 1_000
  @typeKey "type"
  @ping "ping"
  @pong "pong"
  
  # Public

  @spec connect(binary, integer) :: {:ok, port} | {:error, binary}
  def connect(host, port) do
    opts = [:binary, :inet, active: false, packet: 4]
    :gen_tcp.connect(host |> to_charlist, port, opts, @timeout)
  end

  @spec ping(port) :: :ok | {:error, binary}
  def ping(socket) do
    msg = %{@typeKey => @ping} 
    |> Jason.encode!

    with :ok <- :gen_tcp.send(socket, msg),
    {:ok, msg} <- :gen_tcp.recv(socket, 0),
    %{@typeKey => @pong} <- Jason.decode!(msg) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  @spec send(port, map) :: {:ok, map} | {:error, binary}
  def send(socket, json) do
    with msg <- Jason.encode!(json),
    :ok <- :gen_tcp.send(socket, msg),
    {:ok, response} <- :gen_tcp.recv(socket, 0),
    respons_json <- Jason.decode!(response) do
      {:ok, respons_json}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  @spec close(port) :: :ok
  def close(socket) do
    :gen_tcp.shutdown(socket, :write)
    :gen_tcp.close(socket)
  end
end