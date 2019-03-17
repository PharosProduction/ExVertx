defmodule ExVertx.BusService do
  @moduledoc false

  # Public

  @spec connect(binary, integer) :: {:ok, port} | {:error, atom}
  def connect(host, port, timeout \\ :infinity) do
    opts = [:binary, :inet, active: false, packet: 4]
    :gen_tcp.connect(host |> to_charlist, port, opts, timeout)
  end

  @spec ping(port) :: :ok | {:error, binary}
  def ping(socket, timeout \\ :infinity) do
    msg = %{"type" => "ping"}
    |> Jason.encode!

    with :ok <- :gen_tcp.send(socket, msg),
    {:ok, msg} <- :gen_tcp.recv(socket, 0, timeout),
    %{"type" => "pong"} <- Jason.decode!(msg) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  @spec send(port, binary, map, map, binary) :: {:ok, map} | {:error, atom}
  def send(socket, address, body, headers, reply_address, timeout \\ :infinity) do
    json = %{
      "type" => "send",
      "address" => address,
      "body" => body,
      "headers" => headers,
      "replyAddress" => reply_address
    }

    with msg <- Jason.encode!(json),
    :ok <- :gen_tcp.send(socket, msg),
    {:ok, response} <- :gen_tcp.recv(socket, 0, timeout),
    respons_json <- Jason.decode!(response) do
      {:ok, respons_json}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec publish(port, binary, map, map) :: :ok
  def publish(socket, address, body, headers) do
    msg = %{
      "type" => "publish",
      "address" => address,
      "body" => body,
      "headers" => headers
    } |> Jason.encode!

    :gen_tcp.send(socket, msg)
  end

  @spec register(port, binary, map) :: :ok
  def register(socket, address, headers) do
    msg = %{
      "type" => "register",
      "address" => address,
      "headers" => headers
    } |> Jason.encode!

    :gen_tcp.send(socket, msg)
  end

  @spec listen(port, integer | :infinity) :: :ok
  def listen(socket, timeout \\ :infinity) do
    :gen_tcp.recv(socket, 0, timeout)
  end

  @spec unregister(port, binary) :: :ok
  def unregister(socket, address) do
    msg = %{
      "type" => "unregister",
      "address" => address
    } |> Jason.encode!
    IO.puts "UNREGISTER"
    :ok = :gen_tcp.send(socket, msg)
  end

  @spec close(port) :: :ok | {:error, atom}
  def close(socket) do
    IO.puts "CLOSE SOCKET"
    with :ok <- :gen_tcp.shutdown(socket, :write),
    :ok <- :gen_tcp.close(socket) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
