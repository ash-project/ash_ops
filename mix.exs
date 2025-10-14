# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.MixProject do
  use Mix.Project

  @moduledoc "An Ash extension which generates mix tasks for Ash actions"
  @version "0.2.4"
  def project do
    [
      aliases: aliases(),
      app: :ash_ops,
      compilers: compilers(Mix.env()),
      consolidate_protocols: Mix.env() != :dev,
      deps: deps(),
      description: @moduledoc,
      dialyzer: [plt_add_apps: [:mix]],
      docs: docs(),
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  defp package do
    [
      maintainers: [
        "James Harton <james@harton.dev>"
      ],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/ash-project/ash_ops",
        "Changelog" => "https://github.com/ash-project/ash_ops/blob/main/CHANGELOG.md",
        "Discord" => "https://discord.gg/HTHRaaVPUc",
        "Website" => "https://ash-hq.org",
        "Forum" => "https://elixirforum.com/c/elixir-framework-forums/ash-framework-forum",
        "REUSE Compliance" => "https://api.reuse.software/info/github.com/ash-project/ash_ops"
      },
      source_url: "https://github.com/ash-project/ash_ops",
      files: ~w[lib src .formatter.exs mix.exs README* LICENSE* CHANGELOG* documentation]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "documentation/dsls/DSL-AshOps.md"],
      filter_modules: ~r/^Elixir\.AshOps/
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:jason, "~> 1.0"},
      {:spark, "~> 2.0"},
      {:splode, "~> 0.2"},
      {:yaml_elixir, "~> 2.11"},
      {:ymlr, "~> 5.0"},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false},
      {:faker, "~> 0.18", only: [:dev, :test]},
      {:git_ops, "~> 2.0", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.5", only: [:dev, :test], optional: true},
      {:neotoma_compiler, "~> 0.1", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:simple_sat, "~> 0.1", only: [:dev, :test]},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:sourceror, "~> 1.7", only: [:dev, :test], optional: true}
    ]
  end

  defp aliases do
    [
      "spark.formatter": "spark.formatter --extensions AshOps",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions AshOps",
      docs: ["spark.cheat_sheets", "docs"],
      credo: "credo --strict"
    ]
  end

  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp compilers(env) when env in ~w[dev test]a, do: [:neotoma | Mix.compilers()]
  defp compilers(_env), do: Mix.compilers()
end
