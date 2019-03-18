defmodule ExVertx.BusService do
  @moduledoc false

  # Public

  @spec connect([host: binary, port: integer, timeout: integer | :infinity]) :: {:ok, port} | {:error, atom}
  def connect(host: host, port: port, timeout: timeout) do
    opts = [:binary, :inet, active: false, packet: 4]
    :gen_tcp.connect(host |> to_charlist, port, opts, timeout)
  end

  @spec ping(port, [timeout: integer | :infinity]) :: :ok | {:error, binary}
  def ping(socket, timeout: timeout) do
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

  @spec send(port, [address: binary, body: map, headers: map, reply_address: binary, timeout: integer | :infinity])
  :: {:ok, map} | {:error, atom}
  def send(socket, address: address, body: body, headers: headers, reply_address: reply_address, timeout: timeout) do
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

  @spec publish(port, [address: binary, body: map, headers: map]) :: :ok
  def publish(socket, address: address, body: body, headers: headers) do
    msg = %{
      "type" => "publish",
      "address" => address,
      "body" => body,
      "headers" => headers
    } |> Jason.encode!

    :gen_tcp.send(socket, msg)
  end

  @spec register(port, [address: binary, headers: map]) :: :ok
  def register(socket, address: address, headers: headers) do
    msg = %{
      "type" => "register",
      "address" => address,
      "headers" => headers
    } |> Jason.encode!

    :gen_tcp.send(socket, msg)
  end

  @spec listen(pid, port, [timeout: integer | :infinity]) :: {:error, atom}
  def listen(from, socket, timeout: timeout) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:error, reason} -> {:error, reason}
      {:ok, response} ->
        Kernel.send(from, response)
        listen(from, socket, timeout: timeout)
    end
  end

  @spec unregister(port, [address: binary]) :: :ok
  def unregister(socket, address: address) do
    msg = %{
      "type" => "unregister",
      "address" => address
    } |> Jason.encode!

    :gen_tcp.send(socket, msg)
  end

  @spec close(port) :: :ok | {:error, atom}
  def close(socket) do
    with :ok <- :gen_tcp.shutdown(socket, :write),
    :ok <- :gen_tcp.close(socket) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
