defmodule ExVertx.Listener do
  use GenServer

  @event_host = "localhost"
  @event_port = 6_000
  @event_address = "test.time-send"

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
    with {:ok, _pid} <- ExVertx.start_server({self(), make_ref()}, @event_address, @event_host, @event_port),
    :ok <- ExVertx.register(@event_address) do
      {:noreply, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_info(msg, state) when length(state) < 3 do
    {:noreply, [msg | state]}
  end
  def handle_info(msg, state) do
    IO.puts "STATE: #{inspect state}"
    a = ExVertx.unregister(@event_address)
    b = ExVertx.stop(@event_address)

    {:noreply, state}
  end
end