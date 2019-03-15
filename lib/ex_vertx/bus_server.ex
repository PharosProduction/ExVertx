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

  @spec publish(binary, map, map) :: :ok
  def publish(address, body, headers) do
    params = [
      address: address,
      body: body,
      headers: headers
    ]

    with [pid | _] <- :gproc.lookup_pids(topic(address)) do
      :gen_statem.call(pid, {:publish, params}, @timeout)
    else
      [] -> {:error, :not_found}
    end
  end

  @spec register(binary, map) :: :ok
  def register(address, headers) do
    params = [
      address: address,
      headers: headers
    ]

    [pid | _] = :gproc.lookup_pids(topic(address))
    :gen_statem.call(pid, {:register, params}, @timeout)
  end

  @spec unregister(binary) :: :ok
  def unregister(address) do
    [pid | _] = :gproc.lookup_pids(topic(address))
    :gen_statem.call(pid, {:unregister, address: address}, @timeout)
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

  def connected({:call, from}, :get_state, _), do: {:keep_state_and_data, {:reply, from, :connected}}
  def connected(:internal, :ping, %{socket: socket} = data) do
    with :ok <- BusService.ping(socket) do
      {:next_state, :ready, data}
    else
      {:error, _reason} -> {:keep_state_and_data, []}
    end
  end
  def connected({:call, from}, _, _), do: {:keep_state_and_data, {:reply, from, :not_allowed}}

  def ready({:call, from}, :get_state, _), do: {:keep_state_and_data, {:reply, from, :ready}}
  def ready({:call, from}, {:send, params}, %{socket: socket}) do
    [
      address: address,
      body: body,
      headers: headers,
      reply_address: reply_address
    ] = params

    with {:ok, response} <- BusService.send(socket, address, body, headers, reply_address) do
      actions = [
        {:state_timeout, @timeout, :code_expired},
        {:reply, from, {:ok, response}}
      ]

      {:keep_state_and_data, actions}
    else
      {:error, reason} ->
        actions = [
          {:state_timeout, @timeout, :code_expired},
          {:reply, from, {:error, reason}}
        ]

        {:keep_state_and_data, actions}
    end
  end
  def ready({:call, from}, {:publish, params}, %{socket: socket}) do
    [
      address: address,
      body: body,
      headers: headers
    ] = params

    :ok = BusService.publish(socket, address, body, headers)

    actions = [
      {:state_timeout, @timeout, :code_expired},
      {:reply, from, :ok}
    ]

    {:keep_state_and_data, actions}
  end
  def ready({:call, from}, {:register, params}, %{socket: socket}) do
    [
      address: address,
      headers: headers
    ] = params

    :ok = BusService.register(socket, address, headers)

    actions = [
      {:state_timeout, @timeout, :code_expired},
      {:reply, from, :ok}
    ]

    {:keep_state_and_data, actions}
  end
  def ready({:call, from}, {:unregister, address: address}, %{socket: socket}) do
    :ok = BusService.unregister(socket, address)

    actions = [
      {:state_timeout, @timeout, :code_expired},
      {:reply, from, :ok}
    ]

    {:keep_state_and_data, actions}
  end
  def ready({:call, from}, _, _), do: {:keep_state_and_data, {:reply, from, :not_allowed}}

  # Callbacks

  @impl true
  def init([{:address, address}, {:host, host}, {:port, port} | _params]) do
    :gproc.reg(topic(address))

    with {:ok, socket} <- BusService.connect(host, port) do
      data = %{address: address, socket: socket}
      actions = [{:next_event, :internal, :ping}]

      {:ok, :connected, data, actions}
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
