defmodule PgLargeObjects.MixProject do
  use Mix.Project

  def project do
    [
      app: :pg_large_objects,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: dialyzer(Mix.env()),

      # For packaging
      description: "An Elixir library for working with large objects in PostgreSQL databases.",
      package: [
        licenses: ["BSD-2-Clause"],
        links: %{"GitHub" => "https://github.com/frerich/pg_large_objects"}
      ],

      # For documentation
      name: "PgLargeObjects",
      source_url: "https://github.com/frerich/pg_large_objects",
      docs: [
        main: "readme",
        extras: ["README.md", "LICENSE.md", "cheatsheet.cheatmd", "CHANGELOG.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp aliases do
    [
      test: ["ecto.create --quiet", "test"]
    ]
  end

  defp dialyzer(:test) do
    [
      plt_add_apps: [:ex_unit]
    ]
  end

  defp dialyzer(_env), do: []
end
