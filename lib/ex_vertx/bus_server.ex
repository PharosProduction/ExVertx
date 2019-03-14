defmodule ExVertx.BusServer do
  @moduledoc false

  alias ExVertx.BusService

  require Logger

  @hibernate 60_000

  @behaviour :gen_statem

  # Public

  def child_spec([{:id, id} | _] = args) do
    %{
      id: id,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient,
      type: :worker
    }
  end

  @spec start_link(list) :: no_return
  def start_link([{:id, id} | _params] = args) do
    opts = [
      name: via(id),
      hibernate_after: @hibernate
    ]
    :gen_statem.start_link(__MODULE__, args, opts)
  end

  def get_state(id) do
    with [pid | _] <- :gproc.lookup_pids(topic(id)) do
      :gen_statem.call(pid, :get_state, 1_000)
    else
      [] -> {:error, :not_found}
    end
  end

  def send(id) do
    json = %{
      "type" => "send",
      "address" => "test.echo",
      "body" => %{"counter" => 5},
      "headers" => %{},
      "replyAddress" => "test.echo.reply"
    }

    with [pid | _] <- :gproc.lookup_pids(topic(id)),
    {:ok, response} <- :gen_statem.call(pid, {:send, json}, 1_000) do
      {:ok, response}
    else
      [] -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def stop(id) do
    with [pid | _] <- :gproc.lookup_pids(topic(id)) do
      :gen_statem.stop(pid)
    else
      [] -> {:error, :not_found}
    end
  end

  # States

  def ready({:call, from}, :get_state, _), do: {:keep_state_and_data, {:reply, from, :ready}}
  def ready({:call, from}, {:send, msg}, %{socket: socket}) do
    {:ok, response} = BusService.send(socket, msg)

    actions = [
      {:state_timeout, 1_000, :code_expired},
      {:reply, from, {:ok, response}}
    ]

    {:keep_state_and_data, actions}
  end
  def ready({:call, from}, _, _), do: {:keep_state_and_data, {:reply, from, :not_allowed}}

  # Callbacks

  @impl true
  def init([{:id, id} | _params]) do
    :gproc.reg(topic(id))

    with {:ok, socket} <- BusService.connect("localhost", 6000),
    :ok <- BusService.ping(socket) do
      data = %{id: id, socket: socket}
      {:ok, :ready, data, []}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def callback_mode, do: :state_functions

  @impl true
  def terminate(_reason, _state, %{socket: socket}) do
    :ok = BusService.close(socket)

    :nothing
  end

  # Private

  defp topic(id), do: {:n, :l, {:bus_service, id}}

  defp via(id), do: {:via, :gproc, topic(id)}
end
