# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
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
    with :ok <- verify_arguments(task, dsl) do
      verify_identity(task, dsl)
    end
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

  defp verify_identity(%{identity: nil}, _dsl), do: :ok
  defp verify_identity(%{identity: false}, _dsl), do: :ok

  defp verify_identity(%{identity: identity} = task, dsl) when is_atom(identity) do
    identities = Ash.Resource.Info.identities(task.resource)

    case Enum.find(identities, &(&1.name == identity)) do
      nil ->
        identity_names = Enum.map(identities, & &1.name)

        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :identity],
           message: """
           The resource `#{inspect(task.resource)}` does not have an identity named `#{inspect(identity)}`.

           #{if Enum.empty?(identity_names), do: "This resource has no identities defined.", else: "Available identities: #{inspect(identity_names)}"}
           """
         )}

      _identity_info ->
        :ok
    end
  end

  defp verify_identity(_task, _dsl), do: :ok
end
