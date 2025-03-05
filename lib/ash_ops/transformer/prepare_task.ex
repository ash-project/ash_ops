defmodule AshOps.Transformer.PrepareTask do
  @moduledoc """
  A Spark DSL transformer for all `mix_tasks` entities.
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
    |> Enum.reduce_while({:ok, dsl}, fn task, {:ok, dsl} ->
      case transform_entity(task, dsl) do
        {:ok, dsl} -> {:cont, {:ok, dsl}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp transform_entity(task, dsl) do
    with :ok <- validate_resource(task, dsl),
         {:ok, action} <- validate_action(task, dsl),
         {:ok, task} <- validate_read_action(task, dsl),
         {:ok, task} <- set_domain(%{task | action: action}, dsl),
         {:ok, task} <- set_prefix(task, dsl),
         {:ok, task} <- set_task_name(task),
         {:ok, dsl} <- gen_task(task, dsl) do
      {:ok, replace_entity(dsl, [:mix_tasks], task)}
    end
  end

  defp validate_resource(task, dsl) do
    dsl
    |> ADI.resource(task.resource)
    |> case do
      {:ok, _resource} ->
        :ok

      {:error, _reason} ->
        module = get_persisted(dsl, :module)

        {:error,
         DslError.exception(
           module: module,
           path: [:mix_tasks, :get, task.name, :resource],
           message: """
           The resource `#{inspect(task.resource)}` is not a member of the `#{inspect(module)}` domain.
           """
         )}
    end
  end

  defp validate_action(task, dsl) do
    task.resource
    |> ARI.action(task.action)
    |> case do
      action when action.type == :read and task.type in [:get, :list] ->
        {:ok, action}

      action when action.type == task.type ->
        {:ok, action}

      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :action],
           message: """
           The resource `#{inspect(task.resource)}` has no action named `#{inspect(task.action)}`.
           """
         )}

      action when task.type in [:get, :list] ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :action],
           message: """
           Expected the action `#{task.action}` on the `#{inspect(task.resource)}` resource to be a #{task.type}, but it is a #{action.type}.
           """
         )}

      action ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :action],
           message: """
           Expected the action `#{task.action}` on the `#{inspect(task.resource)}` resource to be a #{task.type}, but it is a #{action.type}.
           """
         )}
    end
  end

  defp validate_read_action(task, dsl) when is_nil(task.read_action) do
    task.resource
    |> ARI.actions()
    |> Enum.find(&(&1.type == :read && &1.primary? == true))
    |> case do
      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :read_action],
           message: """
           Task requires a read action, but none was provided and no primary read is set.
           """
         )}

      action ->
        {:ok, %{task | read_action: action}}
    end
  end

  defp validate_read_action(task, dsl) when is_atom(task.read_action) do
    task.resource
    |> ARI.action(task.read_action)
    |> case do
      %{type: :read} = action ->
        {:ok, %{task | read_action: action}}

      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :read_action],
           message: """
           There is no read action named `#{task.read_action}` on the resource.
           """
         )}

      action ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :read_action],
           message: """
           Expected the action `#{task.read_action}` to be a read. It is a `#{action.type}`
           """
         )}
    end
  end

  defp validate_read_action(task, _dsl), do: {:ok, task}

  defp set_domain(task, dsl) do
    {:ok, %{task | domain: get_persisted(dsl, :module)}}
  end

  defp set_prefix(task, dsl) when is_nil(task.prefix) do
    case get_persisted(dsl, :otp_app) do
      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:mix_tasks, task.type, task.name, :prefix],
           message: """
           Unable to set default mix task prefix because the `:otp_app` option is missing from the domain.

           Either set the `prefix` option directly, or add `otp_app: :my_app` to the `use Ash.Domain` statement in this module.
           """
         )}

      app when is_atom(app) ->
        {:ok, %{task | prefix: app}}
    end
  end

  defp set_prefix(task, _dsl) when is_atom(task.prefix), do: {:ok, task}

  defp set_task_name(task) when is_binary(task.task_name), do: {:ok, task}

  defp set_task_name(task) do
    domain =
      task.domain
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    {:ok, %{task | task_name: "#{task.prefix}.#{domain}.#{task.name}"}}
  end

  defp gen_task(task, dsl) do
    mix_task_module_name =
      task.task_name
      |> String.replace(".", "/")
      |> Macro.camelize()
      |> then(&Module.concat("Mix.Tasks", &1))

    ash_ops_task_module_name =
      task.type
      |> to_string()
      |> Macro.camelize()
      |> then(&Module.concat("AshOps.Task", &1))

    dsl =
      dsl
      |> eval(
        [
          ash_ops_task_module_name: ash_ops_task_module_name,
          task: task,
          mix_task_module_name: mix_task_module_name
        ],
        quote do
          defmodule unquote(mix_task_module_name) do
            use unquote(ash_ops_task_module_name), task: unquote(Macro.escape(task))
          end
        end
      )

    {:ok, dsl}
  end
end
