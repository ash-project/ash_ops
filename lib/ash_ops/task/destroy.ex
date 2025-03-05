defmodule AshOps.Task.Destroy do
  @moduledoc """
  Provides the implementation of the `destroy` mix task.

  This should only ever be called from the mix task itself.
  """
  alias Ash.{Query, Resource.Info}
  alias AshOps.Task.ArgSchema
  require Query
  import AshOps.Task.Common

  @doc false
  def run(argv, task, arg_schema) do
    with {:ok, cfg} <- ArgSchema.parse(arg_schema, argv),
         {:ok, actor} <- load_actor(cfg[:actor], cfg[:tenant]),
         cfg <- Map.put(cfg, :actor, actor),
         :ok <- destroy_record(task, cfg) do
      :ok
    else
      {:error, reason} -> handle_error(reason)
    end
  end

  defp destroy_record(task, cfg) do
    opts =
      cfg
      |> Map.take([:load, :actor, :tenant])
      |> Map.put(:domain, task.domain)
      |> Enum.to_list()

    with {:ok, field} <- identity_or_pk_field(task, cfg) do
      task.resource
      |> Query.new()
      |> Query.filter_input(%{field => %{"eq" => cfg.positional_arguments.id}})
      |> Query.for_read(task.read_action.name)
      |> Ash.bulk_destroy(task.action.name, %{}, opts)
      |> case do
        %{status: :success} -> :ok
        %{errors: errors} -> {:error, Ash.Error.to_error(errors)}
      end
    end
  end

  defp identity_or_pk_field(task, cfg) when is_atom(cfg.identity) and not is_nil(cfg.identity) do
    case Info.identity(task.resource, cfg.identity) do
      %{keys: [field]} -> {:ok, field}
      _ -> {:error, "Composite identity error"}
    end
  end

  defp identity_or_pk_field(task, _cfg) do
    case Info.primary_key(task.resource) do
      [pk] -> {:ok, pk}
      _ -> {:error, "Primary key error"}
    end
  end

  @doc false
  defmacro __using__(opts) do
    quote generated: true do
      @task unquote(opts[:task])
      @arg_schema @task
                  |> ArgSchema.default()
                  |> ArgSchema.prepend_positional(:id, "A unique identifier for the record")
                  |> ArgSchema.add_switch(
                    :identity,
                    :string,
                    [
                      type: {:custom, AshOps.Task.Types, :identity, [@task]},
                      required: false,
                      doc: "The identity to use to retrieve the record."
                    ],
                    [:i]
                  )

      @shortdoc "Destroy a single `#{inspect(@task.resource)}` record using the `#{@task.action.name}` action"

      @moduledoc """
      #{@shortdoc}

      #{if @task.description, do: "#{@task.description}\n\n"}
      #{if @task.action.description, do: """
        ## Action

        #{@task.action.description}

        """}
      ## Usage

      Records are looked up by their primary key unless the `--identity` option
      is used. The identity must not be composite (ie only contain a single
      field).

      Matching records are destroyed.
      #{ArgSchema.usage(@task, @arg_schema)}
      """
      use Mix.Task

      @requirements ["app.start"]

      @impl Mix.Task
      def run(args) do
        unquote(__MODULE__).run(args, @task, @arg_schema)
      end
    end
  end
end
