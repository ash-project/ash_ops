# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Verifier.VerifyTask do
  @moduledoc """
  A Spark DSL verifier for mix task entities.
  """
  use Spark.Dsl.Verifier
  import Spark.Dsl.Verifier

  alias AshOps.Info, as: AOI
  alias Spark.Error.DslError

  @doc false
  def verify(dsl) do
    dsl
    |> AOI.mix_tasks()
    |> Enum.reduce_while(:ok, fn task, :ok ->
      case verify_entity(task, dsl) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp verify_entity(task, dsl) do
    verify_arguments(task, dsl)
  end

  defp verify_arguments(task, _dsl) when task.arguments == [], do: :ok

  defp verify_arguments(task, dsl) do
    action_arguments =
      task.action.arguments
      |> Enum.filter(& &1.public?)
      |> MapSet.new(& &1.name)

    entity_arguments = MapSet.new(task.arguments)

    entity_arguments
    |> MapSet.difference(action_arguments)
    |> Enum.to_list()
    |> case do
      [] ->
        :ok

      [spurious] ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :arguments],
           message: """
           The action `#{inspect(task.action.name)}` on the `#{inspect(task.resource)}` resource does not accept the following argument, either because it is not defined or not public:

           - `#{inspect(spurious)}`
           """
         )}

      spurious ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :arguments],
           message: """
           The action `#{inspect(task.action.name)}` on the `#{inspect(task.resource)}` resource does not accept the following arguments, either because they are not defined or not public:

           #{Enum.map_join(spurious, "\n", &"- `#{inspect(&1)}`")}
           """
         )}
    end
  end
end
