defmodule ExVertx.BusServer do
  @moduledoc false

  alias ExVertx.BusService

  require Logger

  @timeout 5_000
  @hibernate 60_000

  @behaviour :gen_statem

  # Public

  @spec child_spec(list) :: map
  def child_spec([{:address, address}, {:host, _}, {:port, _} | _] = args) do
    %{
      id: address,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient,
      type: :worker
    }
  end

  @spec start_link(list) :: no_return
  def start_link([{:address, address}, {:host, _}, {:port, _} | _] = args) do
    opts = [
      name: via(address),
      hibernate_after: @hibernate
    ]
    :gen_statem.start_link(__MODULE__, args, opts)
  end

  @spec get_state(binary) :: :ok | {:error, atom}
  def get_state(address) do
    with [pid | _] <- :gproc.lookup_pids(topic(address)) do
      :gen_statem.call(pid, :get_state, @timeout)
    else
      [] -> {:error, :not_found}
    end
  end

  @spec send(binary, map, map, binary) :: {:ok, map} | {:error, atom}
  def send(address, body, headers, reply_address) do
    params = [
      address: address,
      body: body,
      headers: headers,
      reply_address: reply_address
    ]

    with [pid | _] <- :gproc.lookup_pids(topic(address)),
    {:ok, response} <- :gen_statem.call(pid, {:send, params}, @timeout) do
      {:ok, response}
    else
      [] -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec stop(binary) :: :ok | {:error, atom}
  def stop(address) do
    with [pid | _] <- :gproc.lookup_pids(topic(address)) do
      :gen_statem.stop(pid)
    else
      [] -> {:error, :not_found}
    end
  end

  # States

  def ready({:call, from}, :get_state, _), do: {:keep_state_and_data, {:reply, from, :ready}}
  def ready({:call, from}, {:send, params}, %{socket: socket}) do
    [
      address: address,
      body: body,
      headers: headers,
      reply_address: reply_address
    ] = params
    {:ok, response} = BusService.send(socket, address, body, headers, reply_address)

    actions = [
      {:state_timeout, @timeout, :code_expired},
      {:reply, from, {:ok, response}}
    ]

    {:keep_state_and_data, actions}
  end
  def ready({:call, from}, _, _), do: {:keep_state_and_data, {:reply, from, :not_allowed}}

  # Callbacks

  @impl true
  def init([{:address, address} | _params]) do
    :gproc.reg(topic(address))

    with {:ok, socket} <- BusService.connect("localhost", 6000),
    :ok <- BusService.ping(socket) do
      data = %{address: address, socket: socket}
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

  defp topic(address), do: {:n, :l, {:bus_service, address}}

  defp via(address), do: {:via, :gproc, topic(address)}
end
