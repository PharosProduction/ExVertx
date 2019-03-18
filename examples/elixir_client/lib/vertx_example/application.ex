defmodule VertxExample.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {VertxExample.Listener, []}
    ]

    opts = [strategy: :one_for_one, name: VertxExample.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
