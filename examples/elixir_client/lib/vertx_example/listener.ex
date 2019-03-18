defmodule VertxExample.Listener do
  use GenServer

  @event_host "localhost"
  @event_port 6_000
  @event_address "test.time-send"

  # Public

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  # Callbacks

  @impl true
  def init([]) do
    {:ok, [], {:continue, :register}}
  end

  @impl true
  def handle_continue(:register, state) do
    IO.puts "Starting Vert.x bridge"

    with {:ok, _pid} <- ExVertx.start_server({self(), make_ref()}, @event_address, @event_host, @event_port),
    :ok <- ExVertx.register(@event_address) do
      IO.puts "Subscribed to test.time-send address"
      {:noreply, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_info(msg, state) when length(state) < 3 do
    IO.puts "Received a message from Vert.x: #{inspect msg}"

    {:noreply, [msg | state]}
  end
  def handle_info(msg, state) do
    IO.puts "Unregistering from Vert.x connection: #{inspect msg}"
    ExVertx.unregister(@event_address)
    IO.puts "Connection stopped"

    {:noreply, state}
  end
end