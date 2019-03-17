defmodule ExVertx.BusServer do
  @moduledoc false

  alias ExVertx.BusService

  require Logger

  @timeout 5_000
  @hibernate 60_000

  @behaviour :gen_statem

  # Public

  @spec child_spec(list) :: map
  def child_spec([{:address, address}, {:host, _}, {:port, _}| _] = args) do
    %{
      id: address,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient,
      type: :worker
    }
  end

  @spec start_link(list) :: no_return
  def start_link([{:address, address}, {:host, _}, {:port, _}, {:timeout, _} | _] = args) do
    opts = [
      name: via(address),
      hibernate_after: @hibernate
    ]
    :gen_statem.start_link(__MODULE__, args, opts)
  end

  @spec get_state(binary) :: :ok | {:error, atom}
  def get_state(address) do
    case pid(address) do
      {:ok, pid} -> :gen_statem.call(pid, :get_state, @timeout)
      {:error, reason} -> {:error, reason}
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

    case pid(address) do
      {:ok, pid} -> :gen_statem.call(pid, {:send, params}, @timeout)
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

    case pid(address) do
      {:ok, pid} -> :gen_statem.call(pid, {:publish, params}, @timeout)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec register(binary, map) :: :ok
  def register(address, headers) do
    params = [
      address: address,
      headers: headers
    ]

    case pid(address) do
      {:ok, pid} -> :gen_statem.call(pid, {:register, params}, @timeout)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec unregister(binary) :: :ok
  def unregister(address) do
    case pid(address) do
      {:ok, pid} -> :gen_statem.call(pid, :unregister, @timeout)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec stop(binary) :: :ok | {:error, atom}
  def stop(address) do
    case pid(address) do
      {:ok, pid} -> :gen_statem.stop(pid)
      {:error, reason} -> {:error, reason}
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
  def connected({:call, from}, _, _), do: {:keep_state_and_data, {:reply, from, {:not_allowed, :connected}}}

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
  def ready({:call, _from}, {:register, params}, %{socket: socket} = data) do
    [
      address: address,
      headers: headers
    ] = params

    :ok = BusService.register(socket, address, headers)

    actions = [{:next_event, :internal, :registered}]
    {:next_state, :listening, data, actions}
  end
  def ready({:call, from}, _, _), do: {:keep_state_and_data, {:reply, from, {:not_allowed, :ready}}}

  def listening({:call, from}, :get_state, _), do: {:keep_state_and_data, {:reply, from, :listening}}
  def listening(:internal, :registered, %{socket: socket} = data) do
    IO.puts "LISTENING AGAIN"
    timeout = Map.get(data, :timeout, :infinity)

    with {:ok, event} <- BusService.listen(socket, timeout) do
      # {m, f} = callback
      # apply(m, f, [address, event])

      actions = [{:next_event, :internal, :registered}]
      IO.puts "EVENT: #{inspect event}"
      {:keep_state_and_data, actions}
    else
      {:error, reason} -> {:stop, reason}
    end
  end
  def listening({:call, _from}, :unregistered, %{socket: socket, address: address} = data) do
    IO.puts "LISTENING"
    :ok = BusService.unregister(socket, address)

    actions = [{:next_event, :internal, []}]
    {:next_state, :closed, data, actions}
  end
  def listening({:call, from}, _, _), do: {:keep_state_and_data, {:reply, from, {:not_allowed, :listening}}}

  # Callbacks

  @impl true
  def init([{:address, address}, {:host, host}, {:port, port}, {:timeout, timeout} | _params]) do
    :gproc.reg(topic(address))

    with {:ok, socket} <- BusService.connect(host, port) do
      data = %{address: address, socket: socket, timeout: timeout}
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
    with :ok <- BusService.close(socket) do
      :nothing
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private

  defp topic(address), do: {:n, :l, {:bus_service, address}}

  defp via(address), do: {:via, :gproc, topic(address)}

  defp pid(address) do
    address
    |> topic
    |> :gproc.lookup_pids
    |> case do
      [] -> {:error, :not_found}
      [pid | _] -> {:ok, pid}
    end
  end
end
