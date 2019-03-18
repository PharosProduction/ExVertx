defmodule ExVertx.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :ex_vertx,
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_add_deps: :transitive,
        plt_apps: [:erts, :kernel, :stdlib],
        list_unused_filters: true,
        halt_exit_status: true,
        ignore_warnings: "dialyzer.ignore",
        flags: [
          "-Wunmatched_returns",
          "-Werror_handling",
          "-Wrace_conditions",
          "-Wunderspecs",
          "-Wno_opaque"
        ],
      ],
      deps: deps(),
      aliases: aliases(),
      package: package(),

      # Docs
      name: "ExVertx",
      source_ref: "v#{@version}",
      version: @version,
      description: "Elixir to Vert.x TCP bridge connector.",
      source_url: "https://github.com/PharosProduction/ex-vertx",
      homepage_url: "https://pharosproduction.com",
      docs: [
        output: "./docs",
        extras: ["README.md", "LICENSE.nd"]
      ]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Dmytro Nasyrov", "Pharos Production Inc."],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/PharosProduction/ExVertx"}
    ]
  end

  def application do
    [
      mod: {ExVertx.Application, []},
      extra_applications: [:logger],
      extra_applications: [
        :sasl,
        :logger,
        :runtime_tools,
        :observer,
        :wx
      ]
    ]
  end

  defp deps do
    [
      {:gproc, "~> 0.8"},
      {:jason, "~> 1.1"},
      {:ex_doc, "~> 0.19", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.10", only: [:test]},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      credo: ["credo --strict"],
      cover: ["coveralls -u -v"],
      dialyze: ["dialyzer --format dialyzer"]
    ]
  end
end
