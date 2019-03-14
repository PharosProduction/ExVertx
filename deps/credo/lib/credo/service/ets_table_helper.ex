defmodule Credo.Service.ETSTableHelper do
  @moduledoc false

  defmacro __using__(_opts \\ []) do
    quote do
      use GenServer

      alias Credo.Service.ETSTableHelper

      @table_name __MODULE__

      def start_link(opts \\ []) do
        {:ok, _pid} = GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      def get(filename) do
        GenServer.call(__MODULE__, {:get, filename})
      end

      def put(filename, value) do
        GenServer.call(__MODULE__, {:put, filename, value})
      end

      # callbacks

      def init(opts), do: ETSTableHelper.init(@table_name, opts)

      def handle_call(msg, from, current_state),
        do: ETSTableHelper.handle_call(@table_name, msg, from, current_state)
    end
  end

  def init(table_name, _) do
    ets = :ets.new(table_name, [:named_table, read_concurrency: true])

    {:ok, ets}
  end

  def handle_call(table_name, {:get, filename}, _from, current_state) do
    case :ets.lookup(table_name, filename) do
      [{^filename, value}] ->
        {:reply, {:ok, value}, current_state}

      [] ->
        {:reply, :notfound, current_state}
    end
  end

  def handle_call(table_name, {:put, filename, value}, _from, current_state) do
    :ets.insert(table_name, {filename, value})

    {:reply, value, current_state}
  end
end
