# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs.contributors>
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshOps.Install do
    @moduledoc """
    Installs AshOps into a project. Should be called with `mix igniter.install ash_ops`.
    """
    alias Igniter.{Mix.Task, Project.Formatter}

    @shortdoc "Installs AshOps into a project."

    use Task

    @doc false
    @impl Task
    def igniter(igniter) do
      igniter
      |> Formatter.import_dep(:ash_ops)
    end
  end
else
  defmodule Mix.Tasks.AshOps.Install do
    @moduledoc """
    Installs AshOps into a project. Should be called with `mix igniter.install ash_ops`.
    """
    @shortdoc "Installs AshOps into a project."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_ops.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
