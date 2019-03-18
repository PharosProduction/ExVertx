defmodule VertxExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :vertx_example,
      version: "1.0.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {VertxExample.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_vertx, "~> 1.0"}
    ]
  end
end
