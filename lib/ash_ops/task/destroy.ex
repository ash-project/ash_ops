# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Task.Destroy do
  @moduledoc """
  Provides the implementation of the `destroy` mix task.

  This should only ever be called from the mix task itself.
  """
  alias Ash.Query
  alias Ash.Resource.Info
  alias AshOps.Task.ArgSchema

  import AshOps.Task.Common
  require Query

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

    with {:ok, filter} <- build_identity_filter(task, cfg) do
      query =
        task.resource
        |> Query.new()
        |> Query.for_read(task.read_action.name)

      query =
        if filter do
          Query.filter_input(query, filter)
        else
          query
        end

      query
      |> Ash.bulk_destroy(task.action.name, %{}, opts)
      |> case do
        %{status: :success} -> :ok
        %{errors: errors} -> {:error, Ash.Error.to_error(errors)}
      end
    end
  end

  defp build_identity_filter(%{identity: false}, _cfg), do: {:ok, nil}

  defp build_identity_filter(%{identity: nil} = task, cfg) do
    with {:ok, field} <- identity_or_pk_field(task.resource, cfg) do
      {:ok, %{field => %{"eq" => cfg.positional_arguments.id}}}
    end
  end

  defp build_identity_filter(%{identity: identity, resource: resource}, cfg) do
    identity_info =
      resource
      |> Info.identities()
      |> Enum.find(&(&1.name == identity))

    filter =
      identity_info.keys
      |> Enum.map(fn key ->
        {key, %{"eq" => Map.get(cfg.positional_arguments, key)}}
      end)
      |> Map.new()

    {:ok, filter}
  end

  @doc false
  defmacro __using__(opts) do
    quote generated: true do
      @task unquote(opts[:task])
      @arg_schema unquote(__MODULE__).build_arg_schema(@task)

      @shortdoc "Destroy a single `#{inspect(@task.resource)}` record using the `#{@task.action.name}` action"

      @moduledoc """
      #{@shortdoc}

      #{if @task.description, do: "#{@task.description}\n\n"}
      #{if @task.action.description, do: """
        ## Action

        #{@task.action.description}

        """}
      ## Usage

      #{unquote(__MODULE__).usage_description(@task)}

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

  @doc false
  def build_arg_schema(task) do
    task
    |> ArgSchema.default()
    |> add_identity_args(task)
    |> maybe_add_identity_switch(task)
  end

  defp add_identity_args(arg_schema, %{identity: false}), do: arg_schema

  defp add_identity_args(arg_schema, %{identity: nil}) do
    ArgSchema.prepend_positional(arg_schema, :id, "A unique identifier for the record")
  end

  defp add_identity_args(arg_schema, %{identity: identity, resource: resource}) do
    identity_info =
      resource
      |> Info.identities()
      |> Enum.find(&(&1.name == identity))

    identity_info.keys
    |> Enum.reverse()
    |> Enum.reduce(arg_schema, fn key, acc ->
      attr = Info.attribute(resource, key)
      description = attr.description || "The #{key} of the record"
      ArgSchema.prepend_positional(acc, key, description)
    end)
  end

  defp maybe_add_identity_switch(arg_schema, %{identity: nil} = task) do
    ArgSchema.add_switch(
      arg_schema,
      :identity,
      :string,
      [
        type: {:custom, AshOps.Task.Types, :identity, [task]},
        required: false,
        doc: "The identity to use to retrieve the record."
      ],
      [:i]
    )
  end

  defp maybe_add_identity_switch(arg_schema, _task), do: arg_schema

  @doc false
  def usage_description(%{identity: false}) do
    "This task does not add identity arguments. The action handles record lookup via its own arguments."
  end

  def usage_description(%{identity: nil}) do
    """
    Records are looked up by their primary key unless the `--identity` option
    is used. The identity must not be composite (ie only contain a single
    field).
    """
  end

  def usage_description(%{identity: identity}) do
    "Records are looked up by the `#{identity}` identity."
  end
end
