defmodule ExVertx.BusServer do
  @moduledoc false

  alias ExVertx.BusService

  require Logger

  @timeout 5_000
  @hibernate 60_000

  @behaviour :gen_statem

  # Public

  @spec child_spec([from: {pid, reference}, address: binary, host: binary, port: integer, timeout: integer | :infinity])
  :: map
  def child_spec([from: _, address: address, host: _, port: _, timeout: _] = args) do
    %{
      id: address,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient,
      type: :worker
    }
  end

  @spec start_link([from: {pid, reference}, address: binary, host: binary, port: integer, timeout: integer | :infinity])
  :: no_return
  def start_link([from: _, address: address, host: _, port: _, timeout: _] = args) do
    opts = [
      name: via(address),
      hibernate_after: @hibernate
    ]
    :gen_statem.start_link(__MODULE__, args, opts)
  end

  @spec send(list) :: {:ok, map} | {:error, atom}
  def send([address: address, body: _, headers: _, reply_address: _] = args) do
    case pid(address) do
      {:ok, pid} -> :gen_statem.call(pid, {:send, args}, @timeout)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec publish([address: binary, body: map, headers: map]) :: :ok | {:error, :not_found}
  def publish([address: address, body: _, headers: _] = args) do
    case pid(address) do
      {:ok, pid} -> :gen_statem.cast(pid, {:publish, args})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @spec register([address: binary, body: map]) :: :ok | {:error, atom}
  def register([address: address, headers: _] = args) do
    case pid(address) do
      {:ok, pid} -> :gen_statem.cast(pid, {:register, args})
      {:error, reason} -> {:error, reason}
    end
  end

  @spec unregister([address: binary]) :: :ok | {:error, :not_found}
  def unregister(address: address) do
    case pid(address) do
      {:ok, pid} -> :gen_statem.cast(pid, :unregister)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec stop([address: binary]) :: :ok | {:error, :not_found}
  def stop(address: address) do
    case pid(address) do
      {:ok, pid} -> :gen_statem.stop(pid)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # States

  def connected(:internal, :ping, %{from: from, socket: socket, timeout: timeout} = data) do
    case BusService.ping(socket, timeout: timeout) do
      :ok -> {:next_state, :ready, data}
      {:error, reason} -> {:keep_state_and_data, {:reply, from, {:error, reason}}}
    end
  end
  def connected({:call, _}, _, %{from: from}), do: {:keep_state_and_data, {:reply, from, {:not_allowed, :connected}}}

  def ready({:call, _}, {:send, [address: _, body: _, headers: _, reply_address: _] = attrs}, %{from: from, socket: socket}) do
    case BusService.send(socket, attrs) do
      {:ok, response} -> {:keep_state_and_data, {:reply, from, {:ok, response}}}
      {:error, reason} -> {:keep_state_and_data, {:reply, from, {:error, reason}}}
    end
  end
  def ready({:call, _}, {:publish, [address: _, body: _, headers: _] = attrs}, %{from: from, socket: socket}) do
    :ok = BusService.publish(socket, attrs)

    {:keep_state_and_data, {:reply, from, :ok}}
  end
  def ready(:cast, {:register, address: address, headers: headers}, %{socket: socket} = data) do
    :ok = BusService.register(socket, address: address, headers: headers)

    {:next_state, :listening, data, {:next_event, :internal, :registered}}
  end
  def ready({:call, _}, _, %{from: from}), do: {:keep_state_and_data, {:reply, from, {:not_allowed, :ready}}}

  def listening(:internal, :registered, %{from: {pid, _ref}, socket: socket, timeout: timeout}) do
    with {:error, reason} <- BusService.listen(pid, socket, timeout: timeout) do
      {:stop, reason}
    else
      _ -> {:keep_state_and_data, []}
    end
  end
  def listening(:cast, :unregister, %{address: address, socket: socket} = data) do
    :ok = socket
    |> BusService.unregister(address: address)

    {:next_state, :suspended, data, []}
  end
  def listening({:call, _}, _, %{from: from}), do: {:keep_state_and_data, {:reply, from, {:not_allowed, :listening}}}

  def suspended(:internal, :stopping, %{from: from, socket: socket} = data) do
    case BusService.close(socket) do
      :ok -> {:next_state, :stopped, data, {:next_event, :internal, :shutdown}}
      {:error, reason} -> {:keep_state_and_data, {:reply, from, {:error, reason}}}
    end
  end
  def suspended({:call, _}, _, %{from: from}), do: {:keep_state_and_data, {:reply, from, {:not_allowed, :suspended}}}

  def stopped(:internal, :shutdown, %{from: from}) do
    {:keep_state_and_data, [{:reply, from, :stopped}]}
  end
  def stopped({:call, _}, _, %{from: from}), do: {:keep_state_and_data, {:reply, from, {:not_allowed, :stopped}}}

  # Callbacks

  @impl true
  def init(from: from, address: address, host: host, port: port, timeout: timeout) do
    with :ok <- reg(address),
    attrs <- [host: host, port: port, timeout: timeout],
    {:ok, socket} <- BusService.connect(attrs) do
      data = %{
        from: from,
        address: address,
        socket: socket,
        timeout: timeout
      }

      {:ok, :connected, data, {:next_event, :internal, :ping}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def callback_mode, do: :state_functions

  @impl true
  def terminate(_reason, _state, %{socket: socket}) do
    case BusService.close(socket) do
      :ok -> :nothing
      {:error, reason} -> {:error, reason}
    end
  end

  # Private

  defp topic(address), do: {:n, :l, {:bus_service, address}}

  defp via(address), do: {:via, :gproc, topic(address)}

  defp reg(address) do
    address
    |> topic
    |> :gproc.reg
    |> case do
      true -> :ok
      false -> {:error, "Unable to register the process"}
    end
  end

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
