# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs.contributors>
#
# SPDX-License-Identifier: MIT

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
         {:ok, query} <- read_filter(cfg),
         {:ok, query} <- QueryLang.parse(task, query),
         {:ok, actor} <- load_actor(cfg[:actor], cfg[:tenant]),
         {:ok, records} <- load_records(query, task, Map.put(cfg, :actor, actor)),
         {:ok, output} <- serialise_records(records, task.resource, cfg) do
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
    |> maybe_add_sort(cfg[:sort])
    |> Ash.read(opts)
  end

  defp maybe_add_limit(query, nil), do: query

  defp maybe_add_limit(query, limit) when is_integer(limit) and limit >= 0,
    do: Query.limit(query, limit)

  defp maybe_add_offset(query, nil), do: query

  defp maybe_add_offset(query, offset) when is_integer(offset) and offset >= 0,
    do: Query.offset(query, offset)

  defp maybe_add_sort(query, nil), do: query

  defp maybe_add_sort(query, sort),
    do: Query.sort_input(query, sort)

  defp read_filter(cfg) when is_binary(cfg.filter) and cfg.filter_stdin == true,
    do: {:error, "Cannot set both `filter` and `filter-stdin` at the same time"}

  defp read_filter(cfg) when cfg.filter_stdin == true do
    case IO.read(:eof) do
      {:error, reason} -> {:error, "Unable to read query from STDIN: #{inspect(reason)}"}
      :eof -> {:error, "No query received on STDIN"}
      filter -> {:ok, filter}
    end
  end

  defp read_filter(cfg) when is_binary(cfg.filter), do: {:ok, cfg.filter}
  defp read_filter(_), do: {:ok, nil}

  @doc false
  defmacro __using__(opts) do
    quote generated: true do
      @task unquote(opts[:task])
      @arg_schema @task
                  |> ArgSchema.default()
                  |> ArgSchema.add_switch(
                    :filter_stdin,
                    :count,
                    type: {:custom, AshOps.Task.Types, :filter_stdin, []},
                    required: false,
                    doc: "Read a JSON or YAML filter from STDIN"
                  )
                  |> ArgSchema.add_switch(
                    :filter,
                    :string,
                    type: {:custom, AshOps.Task.Types, :filter, []},
                    required: false,
                    doc: "A filter to apply to the filter"
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
                  |> ArgSchema.add_switch(
                    :sort,
                    :string,
                    type: {:custom, AshOps.Task.Types, :sort_input, []},
                    required: false,
                    doc: "An optional sort to apply to the query"
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

      ## Sorting

      You can use [Ash's text based sort format](https://hexdocs.pm/ash/Ash.Query.html#sort/3-format)
      to provide a sorting order for the returned records.

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
