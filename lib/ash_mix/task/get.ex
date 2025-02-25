defmodule AshMix.Task.Get do
  @moduledoc """
  Provides the implementation of the `get` mix task.

  This should only ever be called from the mix task itself.
  """
  alias Ash.{Query, Resource.Info}
  alias AshMix.Task.ArgSchema

  require Query

  @doc false
  def run(argv, task, arg_schema) do
    with {:ok, cfg} <- ArgSchema.parse(arg_schema, argv),
         {:ok, actor} <- load_actor(cfg[:actor], cfg[:tenant]),
         {:ok, record} <- load_record(task, Map.put(cfg, :actor, actor)),
         {:ok, record} <- filter_record(record, task, cfg) do
      serialise_record(record, cfg.format || :yaml)

      :ok
    else
      {:error, reason} -> handle_error({:error, reason})
    end
  end

  defp serialise_record(record, :yaml) do
    record
    |> Map.new(fn
      {key, nil} -> {key, "nil"}
      {key, value} -> {key, value}
    end)
    |> Ymlr.document!()
    |> String.replace_leading("---\n", "")
    |> Mix.shell().info()
  end

  defp serialise_record(record, :json) do
    record
    |> Jason.encode!(pretty: true)
    |> Mix.shell().info()
  end

  defp filter_record(record, task, cfg) do
    result =
      task.resource
      |> Info.public_fields()
      |> Enum.map(& &1.name)
      |> Enum.concat(cfg[:load] || [])
      |> do_filter_record(record)

    {:ok, result}
  end

  defp do_filter_record(fields, record, result \\ %{})
  defp do_filter_record([], _record, result), do: result

  defp do_filter_record([field | fields], record, result) when is_atom(field) do
    case Map.fetch!(record, field) do
      not_loaded when is_struct(not_loaded, Ash.NotLoaded) ->
        do_filter_record(fields, record, result)

      value ->
        do_filter_record(fields, record, Map.put(result, field, value))
    end
  end

  defp do_filter_record([{field, children} | fields], record, result) when is_list(children) do
    value = do_filter_record(children, Map.fetch!(record, field))
    do_filter_record(fields, record, Map.put(result, field, value))
  end

  defp load_record(task, cfg) do
    opts =
      cfg
      |> Map.take([:load, :actor, :tenant])
      |> Map.put(:domain, task.domain)
      |> Map.put(:not_found_error?, true)
      |> Map.put(:authorize_with, :error)
      |> Enum.to_list()

    with {:ok, field} <- identity_or_pk_field(task, cfg) do
      task.resource
      |> Query.new()
      |> Query.for_read(task.action.name)
      |> Query.filter_input(%{field => %{"eq" => cfg.positional_arguments.id}})
      |> Ash.read_one(opts)
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

  defp handle_error({:error, reason}) when is_exception(reason) do
    reason
    |> Exception.message()
    |> Mix.shell().error()
  end

  defp handle_error({:error, reason}) when is_binary(reason) do
    reason
    |> Mix.shell().error()
  end

  defp handle_error({:error, reason}) do
    reason
    |> inspect()
    |> Mix.shell().error()
  end

  defp load_actor(nil, _), do: {:ok, nil}

  defp load_actor({resource, filter}, tenant) do
    resource
    |> Query.new()
    |> Query.filter_input(filter)
    |> Ash.read_one(authorize?: false, tenant: tenant)
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
                    {:custom, AshMix.Task.Types, :identity, [@task]},
                    "The identity to use to retrieve the record.",
                    [:i]
                  )

      @shortdoc "Get a single `#{inspect(@task.resource)}` record using the `#{@task.action.name}` action"

      @moduledoc """
      #{@shortdoc}

      #{if @task.action.description, do: "#{@task.action.description}\n\n"}
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
