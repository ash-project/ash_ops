defmodule AshOps.Task.List do
  @moduledoc """
  Provides the implementation of the `read`` mix task.

  This should only ever be called from the mix task itself.
  """
  alias Ash.{Query, Resource.Info}
  alias AshOps.{QueryLang, Task.ArgSchema}

  import AshOps.Task.Read

  @doc false
  def run(argv, task, arg_schema) do
    with {:ok, cfg} <- ArgSchema.parse(arg_schema, argv),
         {:ok, query} <- read_query(cfg),
         {:ok, query} <- QueryLang.parse(task, query),
         {:ok, actor} <- load_actor(cfg[:actor], cfg[:tenant]),
         {:ok, records} <- load_records(query, task, Map.put(cfg, :actor, actor)) do
      records
      |> filter_records(task, cfg)
      |> serialise_records(cfg.format || :yaml)
    else
      {:error, reason} -> handle_error({:error, reason})
    end
  end

  defp serialise_records(records, :yaml) do
    records
    |> Ymlr.document!()
    |> String.replace_leading("---\n", "")
    |> Mix.shell().info()
  end

  defp serialise_records(records, :json) do
    records
    |> Jason.encode!(pretty: true)
    |> Mix.shell().info()
  end

  defp filter_records(records, task, cfg) do
    fields =
      task.resource
      |> Info.public_fields()
      |> Enum.map(& &1.name)
      |> Enum.concat(cfg[:load] || [])

    Enum.map(records, &filter_record(fields, &1))
  end

  defp filter_record(fields, record, result \\ %{})
  defp filter_record([], _record, result), do: result

  defp filter_record([field | fields], record, result) when is_atom(field) do
    case Map.fetch!(record, field) do
      not_loaded when is_struct(not_loaded, Ash.NotLoaded) ->
        filter_record(fields, record, result)

      value ->
        filter_record(fields, record, Map.put(result, field, value))
    end
  end

  defp filter_record([{field, children} | fields], record, result) do
    value = filter_record(children, Map.fetch!(record, field))
    filter_record(fields, record, Map.put(result, field, value))
  end

  defp load_records(query, task, cfg) do
    opts =
      cfg
      |> Map.take([:load, :actor, :tenant])
      |> Map.put(:domain, task.domain)
      |> Enum.to_list()

    query
    |> maybe_add_limit(cfg[:limit])
    |> maybe_add_offset(cfg[:offset])
    |> Ash.read(opts)
  end

  defp maybe_add_limit(query, nil), do: query

  defp maybe_add_limit(query, limit) when is_integer(limit) and limit >= 0,
    do: Query.limit(query, limit)

  defp maybe_add_offset(query, nil), do: query

  defp maybe_add_offset(query, offset) when is_integer(offset) and offset >= 0,
    do: Query.offset(query, offset)

  defp read_query(cfg) when is_binary(cfg.query) and cfg.query_stdin == true,
    do: {:error, "Cannot set both `query` and `query-stdin` at the same time"}

  defp read_query(cfg) when cfg.query_stdin == true do
    case IO.read(:eof) do
      {:error, reason} -> {:error, "Unable to read query from STDIN: #{inspect(reason)}"}
      :eof -> {:error, "No query received on STDIN"}
      query -> {:ok, query}
    end
  end

  defp read_query(cfg) when is_binary(cfg.query), do: {:ok, cfg.query}
  defp read_query(_), do: {:ok, nil}

  @doc false
  defmacro __using__(opts) do
    quote generated: true do
      @task unquote(opts[:task])
      @arg_schema @task
                  |> ArgSchema.default()
                  |> ArgSchema.add_switch(
                    :query_stdin,
                    :count,
                    {:custom, AshOps.Task.Types, :query_stdin, []},
                    "Read a JSON or YAML query from STDIN"
                  )
                  |> ArgSchema.add_switch(
                    :query,
                    :string,
                    {:custom, AshOps.Task.Types, :query, []},
                    "A filter to apply to the query"
                  )
                  |> ArgSchema.add_switch(
                    :limit,
                    :integer,
                    :non_neg_integer,
                    "An optional limit to put on the number of records returned"
                  )
                  |> ArgSchema.add_switch(
                    :offset,
                    :integer,
                    :non_neg_integer,
                    "An optional number of records to skip"
                  )

      @shortdoc "Query for `#{inspect(@task.resource)}` records using the `#{@task.action.name}` action"

      @moduledoc """
      #{@shortdoc}

      #{if @task.action.description, do: "#{@task.action.description}\n\n"}

      ## Filters

      #{AshOps.QueryLang.doc()}

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
