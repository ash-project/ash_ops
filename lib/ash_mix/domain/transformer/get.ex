defmodule AshMix.Domain.Transformer.Get do
  @moduledoc """
  A Spark DSL transformer for the `get` entity.
  """
  use Spark.Dsl.Transformer
  import Spark.Dsl.Transformer

  alias Ash.Domain.Info, as: ADI
  alias Ash.Resource.Info, as: ARI
  alias AshMix.Domain.Info, as: AMI
  alias Spark.Error.DslError

  @doc false
  @impl true
  def transform(dsl) do
    dsl
    |> AMI.mix_tasks()
    |> Enum.filter(&is_struct(&1, AshMix.Domain.Entity.Get))
    |> Enum.reduce_while({:ok, dsl}, fn get, {:ok, dsl} ->
      case transform_entity(get, dsl) do
        {:ok, dsl} -> {:cont, {:ok, dsl}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp transform_entity(get, dsl) do
    with :ok <- validate_resource(get, dsl),
         {:ok, action} <- validate_action(get, dsl),
         {:ok, get} <- set_domain(%{get | action: action}, dsl),
         {:ok, get} <- set_prefix(get, dsl),
         {:ok, dsl} <- gen_task(get, dsl) do
      {:ok, replace_entity(dsl, [:mix_tasks], get)}
    end
  end

  defp validate_resource(get, dsl) do
    dsl
    |> ADI.resource(get.resource)
    |> case do
      {:ok, _resource} ->
        :ok

      {:error, _reason} ->
        module = get_persisted(dsl, :module)

        {:error,
         DslError.exception(
           module: module,
           path: [:mix_tasks, :get, get.name, :resource],
           message: """
           The resource `#{inspect(get.resource)}` is not a member of the `#{inspect(module)}` domain.
           """
         )}
    end
  end

  defp validate_action(get, dsl) do
    get.resource
    |> ARI.action(get.action)
    |> case do
      action when action.type == :read ->
        {:ok, action}

      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, :get, get.name, :action],
           message: """
           The resource `#{inspect(get.resource)}` has no action named `#{inspect(get.action)}`.
           """
         )}

      action ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, :get, get.name, :action],
           message: """
           Expected the action `#{inspect(get.action)}` on the `#{inspect(get.resource)}` resource to be a read, but it is a #{action.type}.
           """
         )}
    end
  end

  defp set_domain(get, dsl) do
    {:ok, %{get | domain: get_persisted(dsl, :module)}}
  end

  defp set_prefix(get, dsl) when is_nil(get.prefix) do
    case get_persisted(dsl, :otp_app) do
      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, :get, get.name, :prefix],
           message: """
           Unable to set default mix task prefix because the `:otp_app` option is missing from the domain.

           Either set the `prefix` option directly, or add `otp_app: :my_app` to the `use Ash.Domain` statement in this module.
           """
         )}

      app when is_atom(app) ->
        {:ok, %{get | prefix: app}}
    end
  end

  defp set_prefix(get, _dsl) when is_atom(get.prefix), do: {:ok, get}

  defp gen_task(get, dsl) do
    domain =
      get.domain
      |> Module.split()
      |> List.last()

    module =
      [
        "Mix.Tasks",
        Macro.camelize("#{get.prefix}"),
        Macro.camelize("#{domain}"),
        Macro.camelize("#{get.name}")
      ]
      |> Module.concat()

    dsl =
      dsl
      |> eval(
        [domain: domain, get: get, module: module],
        quote do
          defmodule unquote(module) do
            use AshMix.Task.Get, task: unquote(Macro.escape(get))
          end
        end
      )

    {:ok, dsl}
  end
end
