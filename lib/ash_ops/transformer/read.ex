defmodule AshOps.Transformer.Read do
  @moduledoc """
  A Spark DSL transformer for the `get` and `list` entities.
  """
  use Spark.Dsl.Transformer
  import Spark.Dsl.Transformer

  alias Ash.Domain.Info, as: ADI
  alias Ash.Resource.Info, as: ARI
  alias AshOps.Info, as: AOI
  alias Spark.Error.DslError

  @doc false
  @impl true
  def transform(dsl) do
    dsl
    |> AOI.mix_tasks()
    |> Enum.filter(&(is_struct(&1, AshOps.Entity.Get) || is_struct(&1, AshOps.Entity.List)))
    |> Enum.reduce_while({:ok, dsl}, fn read, {:ok, dsl} ->
      case transform_entity(read, dsl) do
        {:ok, dsl} -> {:cont, {:ok, dsl}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp transform_entity(read, dsl) do
    with :ok <- validate_resource(read, dsl),
         {:ok, action} <- validate_action(read, dsl),
         {:ok, read} <- set_domain(%{read | action: action}, dsl),
         {:ok, read} <- set_prefix(read, dsl),
         {:ok, dsl} <- gen_task(read, dsl) do
      {:ok, replace_entity(dsl, [:mix_tasks], read)}
    end
  end

  defp validate_resource(read, dsl) do
    dsl
    |> ADI.resource(read.resource)
    |> case do
      {:ok, _resource} ->
        :ok

      {:error, _reason} ->
        module = get_persisted(dsl, :module)

        {:error,
         DslError.exception(
           module: module,
           path: [:mix_tasks, :get, read.name, :resource],
           message: """
           The resource `#{inspect(read.resource)}` is not a member of the `#{inspect(module)}` domain.
           """
         )}
    end
  end

  defp validate_action(read, dsl) do
    read.resource
    |> ARI.action(read.action)
    |> case do
      action when action.type == :read ->
        {:ok, action}

      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, read.type, read.name, :action],
           message: """
           The resource `#{inspect(read.resource)}` has no action named `#{inspect(read.action)}`.
           """
         )}

      action ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, read.type, read.name, :action],
           message: """
           Expected the action `#{inspect(read.action)}` on the `#{inspect(read.resource)}` resource to be a read, but it is a #{action.type}.
           """
         )}
    end
  end

  defp set_domain(get, dsl) do
    {:ok, %{get | domain: get_persisted(dsl, :module)}}
  end

  defp set_prefix(read, dsl) when is_nil(read.prefix) do
    case get_persisted(dsl, :otp_app) do
      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, read.type, read.name, :prefix],
           message: """
           Unable to set default mix task prefix because the `:otp_app` option is missing from the domain.

           Either set the `prefix` option directly, or add `otp_app: :my_app` to the `use Ash.Domain` statement in this module.
           """
         )}

      app when is_atom(app) ->
        {:ok, %{read | prefix: app}}
    end
  end

  defp set_prefix(read, _dsl) when is_atom(read.prefix), do: {:ok, read}

  defp gen_task(read, dsl) when read.type == :get do
    domain =
      read.domain
      |> Module.split()
      |> List.last()

    module =
      [
        "Mix.Tasks",
        Macro.camelize("#{read.prefix}"),
        Macro.camelize("#{domain}"),
        Macro.camelize("#{read.name}")
      ]
      |> Module.concat()

    dsl =
      dsl
      |> eval(
        [domain: domain, read: read, module: module],
        quote do
          defmodule unquote(module) do
            use AshOps.Task.Get, task: unquote(Macro.escape(read))
          end
        end
      )

    {:ok, dsl}
  end

  defp gen_task(read, dsl) when read.type == :list do
    domain =
      read.domain
      |> Module.split()
      |> List.last()

    module =
      [
        "Mix.Tasks",
        Macro.camelize("#{read.prefix}"),
        Macro.camelize("#{domain}"),
        Macro.camelize("#{read.name}")
      ]
      |> Module.concat()

    dsl =
      dsl
      |> eval(
        [domain: domain, read: read, module: module],
        quote do
          defmodule unquote(module) do
            use AshOps.Task.List, task: unquote(Macro.escape(read))
          end
        end
      )

    {:ok, dsl}
  end
end
