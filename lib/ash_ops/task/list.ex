defmodule AshOps.Task.List do
  @moduledoc """
  Provides the implementation of the `list` mix task.

  This should only ever be called from the mix task itself.
  """
  alias Ash.Query
  alias AshOps.{QueryLang, Task.ArgSchema}

  import AshOps.Task.Common

  @doc false
  def run(argv, task, arg_schema) do
    with {:ok, cfg} <- ArgSchema.parse(arg_schema, argv),
         {:ok, query} <- read_query(cfg),
         {:ok, query} <- QueryLang.parse(task, query),
         {:ok, actor} <- load_actor(cfg[:actor], cfg[:tenant]),
         {:ok, records} <- load_records(query, task, Map.put(cfg, :actor, actor)),
         {:ok, output} <- serialise_records(records, task, cfg) do
      Mix.shell().info(output)

      :ok
    else
      {:error, reason} -> handle_error({:error, reason})
    end
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
                    type: {:custom, AshOps.Task.Types, :query_stdin, []},
                    required: false,
                    doc: "Read a JSON or YAML query from STDIN"
                  )
                  |> ArgSchema.add_switch(
                    :query,
                    :string,
                    type: {:custom, AshOps.Task.Types, :query, []},
                    required: false,
                    doc: "A filter to apply to the query"
                  )
                  |> ArgSchema.add_switch(
                    :limit,
                    :integer,
                    type: :non_neg_integer,
                    doc: "An optional limit to put on the number of records returned",
                    required: false
                  )
                  |> ArgSchema.add_switch(
                    :offset,
                    :integer,
                    type: :non_neg_integer,
                    required: false,
                    doc: "An optional number of records to skip"
                  )

      @shortdoc "Query for `#{inspect(@task.resource)}` records using the `#{@task.action.name}` action"

      @moduledoc """
      #{@shortdoc}

      #{if @task.description, do: "#{@task.description}\n\n"}

      #{if @task.action.description, do: """
        ## Action

        #{@task.action.description}

        """}
      ## Usage

      Without a query, this task will return all records returned by the
      `#{@task.action.name}` read action. You can optionally provide a query
      using the filter language documented below to provide additional filters
      into the query.

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
