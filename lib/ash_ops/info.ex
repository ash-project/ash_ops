# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Info do
  @moduledoc """
  Auto-generated introspection for the `AshOps` extension.
  """
  use Spark.InfoGenerator, extension: AshOps, sections: [:mix_tasks]

  @type domain_or_dsl :: module | Spark.Dsl.t()

  @doc """
  Get a mix task by name.
  """
  @spec mix_task(domain_or_dsl, atom) :: {:ok, AshOps.entity()} | {:error, any}
  def mix_task(domain, name) do
    domain
    |> mix_tasks()
    |> Enum.reduce_while({:error, "No mix task named `#{inspect(name)}`"}, fn
      %{name: ^name} = task, _ -> {:halt, {:ok, task}}
      _task, error -> {:cont, error}
    end)
  end

  @doc "Raising version of `mix_task/2`"
  @spec mix_task!(domain_or_dsl, atom) :: AshOps.entity() | no_return
  def mix_task!(domain, name) do
    case mix_task(domain, name) do
      {:ok, task} -> task
      {:error, reason} -> raise reason
    end
  end
end
