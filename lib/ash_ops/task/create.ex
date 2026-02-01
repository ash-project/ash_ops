# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Task.Create do
  @moduledoc """
  Provides the implementation of the `create` mix task.

  This should only ever be called from the mix task itself.
  """

  alias Ash.{Changeset, Resource.Info}
  alias AshOps.Task.ArgSchema
  import AshOps.Task.Common

  @doc false
  def run(argv, task, arg_schema) do
    with {:ok, cfg} <- ArgSchema.parse(arg_schema, argv),
         {:ok, changeset} <- read_input(task, cfg),
         {:ok, record} <- create_record(changeset, task, cfg),
         {:ok, output} <- serialise_record(record, task.resource, cfg) do
      Mix.shell().info(output)
      :ok
    else
      {:error, reason} -> handle_error({:error, reason})
    end
  end

  defp create_record(changeset, task, cfg) do
    opts =
      cfg
      |> Map.take([:load, :actor, :tenant])
      |> Map.put(:domain, task.domain)
      |> Enum.to_list()

    changeset
    |> Changeset.for_create(task.action)
    |> Ash.create(opts)
  end

  defp read_input(task, cfg) when cfg.input == :interactive do
    argument_names =
      task.action.arguments
      |> Enum.filter(& &1.public?)
      |> MapSet.new(& &1.name)

    inputs =
      task.action.accept
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(task.action.reject))
      |> MapSet.union(argument_names)

    changeset =
      task.resource
      |> Changeset.new()

    Mix.shell().info(
      IO.ANSI.format([
        "Creating new ",
        :cyan,
        inspect(task.resource),
        :reset,
        " using the ",
        :cyan,
        to_string(task.action.name),
        :reset,
        " action:\n"
      ])
    )

    prompt_for_inputs(inputs, task, changeset)
  end

  defp read_input(task, cfg) when cfg.input == :yaml do
    with {:ok, input} <- read_stdin() do
      case YamlElixir.read_from_string(input) do
        {:ok, map} when is_map(map) ->
          changeset =
            task.resource
            |> Changeset.new()
            |> Changeset.for_create(task.action.name, map)

          {:ok, changeset}

        {:ok, _other} ->
          {:error, "YAML input must be a map"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp read_input(task, cfg) when cfg.input == :json do
    with {:ok, input} <- read_stdin() do
      case Jason.decode(input) do
        {:ok, map} when is_map(map) ->
          changeset =
            task.resource
            |> Changeset.new()
            |> Changeset.for_create(task.action, map)

          {:ok, changeset}

        {:ok, _other} ->
          {:error, "JSON input must be a map"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp read_stdin do
    case IO.read(:eof) do
      {:error, reason} -> {:error, "Unable to read input from STDIN: #{inspect(reason)}"}
      :eof -> {:error, "No input received on STDIN"}
      input -> {:ok, input}
    end
  end

  defp prompt_for_inputs(inputs, task, changeset) do
    arguments =
      task.action.arguments
      |> Enum.filter(& &1.public?)
      |> Map.new(&{&1.name, &1})

    Enum.reduce_while(inputs, {:ok, changeset}, fn input_name, {:ok, changeset} ->
      {input_type, entity} =
        if is_map_key(arguments, input_name) do
          {:argument, Map.fetch!(arguments, input_name)}
        else
          attribute = Info.attribute(task.resource, input_name)
          {:attribute, attribute}
        end

      case prompt_for_input(
             input_name,
             input_type,
             task,
             changeset,
             entity
           ) do
        {:ok, changeset} -> {:cont, {:ok, changeset}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp prompt_for_input(input_name, input_type, task, changeset, entity, retries \\ 3)

  defp prompt_for_input(input_name, input_type, task, changeset, entity, 0) do
    prompt =
      IO.ANSI.format([
        "Looks like you're having trouble entering the ",
        :cyan,
        to_string(input_name),
        :reset,
        " #{input_type}. Would you like to keep trying?"
      ])
      |> IO.iodata_to_binary()

    if Mix.shell().yes?(prompt) do
      prompt_for_input(input_name, input_type, task, changeset, entity, 3)
    else
      {:error, "Aborted while entering `#{input_name}` #{input_type}."}
    end
  end

  defp prompt_for_input(input_name, input_type, task, input_changeset, entity, retries) do
    prompt =
      IO.ANSI.format([
        "[",
        :cyan,
        to_string(input_name),
        :reset,
        "](",
        describe_type(entity.type, entity.constraints),
        "):"
      ])
      |> IO.iodata_to_binary()

    input =
      prompt
      |> Mix.shell().prompt()
      |> String.trim()

    changeset =
      case input_type do
        :attribute -> Changeset.change_attribute(input_changeset, input_name, input)
        :argument -> Changeset.set_argument(input_changeset, input_name, input)
      end

    changeset
    |> Changeset.for_create(task.action)
    |> Map.get(:errors, [])
    |> Enum.filter(&(&1.field == input_name))
    |> case do
      [] ->
        {:ok, changeset}

      errors ->
        Mix.shell().error(Ash.Error.error_descriptions(errors))

        prompt_for_input(input_name, input_type, task, input_changeset, entity, retries - 1)
    end
  end

  defp describe_type(type, constraints) do
    if Ash.Type.composite?(type, constraints) do
      Ash.Type.describe(type, constraints)
    else
      Ash.Type.short_names()
      |> Enum.find(&(elem(&1, 1) == type))
      |> case do
        nil -> Ash.Type.describe(type, constraints)
        {short, _} -> to_string(short)
      end
    end
  end

  @doc false
  defmacro __using__(opts) do
    quote generated: true do
      @task unquote(opts[:task])
      @arg_schema @task
                  |> ArgSchema.default()
                  |> ArgSchema.add_switch(
                    :input,
                    :string,
                    [
                      type: {:custom, AshOps.Task.Types, :atom, [[:json, :yaml, :interactive]]},
                      default: "interactive",
                      required: false,
                      doc:
                        "Read action input from STDIN in this format. Valid options are `json`, `yaml` and `interactive`.  Defaults to `interactive`."
                    ],
                    [:i]
                  )

      @shortdoc "Create a `#{inspect(@task.resource)}` record using the `#{@task.action.name}` action"

      @moduledoc """
      #{@shortdoc}

      #{if @task.description, do: "#{@task.description}\n\n"}

      #{if @task.action.description, do: """
        ## Action

        #{@task.action.description}

        """}
      ## Usage

      Action input can be provided via YAML or JSON on STDIN, or interactively.

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
