defmodule ExVertx do

  def ping do
    opts = [:binary, :inet, active: false, packet: 4]
    {:ok, socket} = :gen_tcp.connect("127.0.0.1" |> to_charlist, 6000, opts)

    data = %{"type" => "ping"} 
    |> Jason.encode!
    IO.puts "DATA: #{data}"
    :ok = :gen_tcp.send(socket, data)
    IO.puts "SENT"
    {:ok, msg} = :gen_tcp.recv(socket, 0)
    res = Jason.decode!(msg)
    IO.puts "MSG: #{inspect res}"

    :ok = :gen_tcp.close(socket)
  end

  def send do
    opts = [:binary, :inet, active: false, packet: 4]
    {:ok, socket} = :gen_tcp.connect("127.0.0.1" |> to_charlist, 6000, opts)
    IO.inspect socket

    # data = %{"type" => "ping"}
    # |> Jason.encode!

    # "replyAddress" => "test.elixir"
    data = %{
      "type" => "send", 
      "address" => "test.echo", 
      "body" => %{"counter" => 5},
      "headers" => %{},
      "replyAddress" => "test.echo.reply"
    } |> Jason.encode!
    IO.puts "DATA: #{data}"

    # :ok = :gen_tcp.send(socket, "{\"type\":\"ping\"}")
    :ok = :gen_tcp.send(socket, data)
    IO.puts "SENT"
    {:ok, msg} = :gen_tcp.recv(socket, 0)
    IO.puts "MSG: #{inspect msg}"

    :ok = :gen_tcp.close(socket)
  end
end
