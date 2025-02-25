defmodule AshMix.Domain.Verifier.Get do
  @moduledoc """
  A Spark DSL verifier for the `get` entity.
  """
  use Spark.Dsl.Verifier
  import Spark.Dsl.Verifier

  alias AshMix.Domain.Info, as: AMI
  alias Spark.Error.DslError

  @doc false
  def verify(dsl) do
    dsl
    |> AMI.mix_tasks()
    |> Enum.filter(&is_struct(&1, AshMix.Domain.Entity.Get))
    |> Enum.reduce_while(:ok, fn get, :ok ->
      case verify_entity(get, dsl) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp verify_entity(get, dsl) do
    verify_arguments(get, dsl)
  end

  defp verify_arguments(get, _dsl) when get.arguments == [], do: :ok

  defp verify_arguments(get, dsl) do
    action_arguments =
      get.action.arguments
      |> Enum.filter(& &1.public?)
      |> MapSet.new(& &1.name)

    entity_arguments = MapSet.new(get.arguments)

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
           path: [:mix_tasks, :get, get.name, :arguments],
           message: """
           The action `#{inspect(get.action.name)}` on the `#{inspect(get.resource)}` resource does not accept the following argument, either because it is not defined or not public:

           - `#{inspect(spurious)}`
           """
         )}

      spurious ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, :get, get.name, :arguments],
           message: """
           The action `#{inspect(get.action.name)}` on the `#{inspect(get.resource)}` resource does not accept the following arguments, either because they are not defined or not public:

           #{Enum.map_join(spurious, "\n", &"- `#{inspect(&1)}`")}
           """
         )}
    end
  end
end
