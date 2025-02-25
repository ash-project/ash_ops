defmodule AshMix.MixProject do
  use Mix.Project

  @version "0.1.0"
  def project do
    [
      app: :ash_mix,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps()
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
      {:sourceror, "~> 1.7", only: [:dev, :test]},
      {:ex_doc, "~> 0.37"},
      {:ex_check, "~> 0.16"},
      {:spark, "~> 2.0"},
      {:credo, "~> 1.0"},
      {:git_ops, "~> 2.0", only: [:dev], runtime: false},
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.5", only: [:dev, :test]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
