defmodule AshOps.Task.Update do
  @moduledoc """
  Provides the implementation of the `update` mix task.

  This should only ever be called from the mix task itself.
  """
  alias Ash.{Changeset, Query, Resource.Info}
  alias AshOps.Task.ArgSchema
  require Query
  import AshOps.Task.Common

  @doc false
  def run(argv, task, arg_schema) do
    with {:ok, cfg} <- ArgSchema.parse(arg_schema, argv),
         {:ok, actor} <- load_actor(cfg[:actor], cfg[:tenant]),
         cfg <- Map.put(cfg, :actor, actor),
         {:ok, record} <- load_record(task, cfg),
         {:ok, changeset} <- read_input(record, task, cfg),
         {:ok, record} <- update_record(changeset, task, cfg),
         {:ok, output} <- serialise_record(record, task.resource, cfg) do
      Mix.shell().info(output)
      :ok
    else
      {:error, reason} -> handle_error({:error, reason})
    end
  end

  defp update_record(changeset, task, cfg) do
    opts =
      cfg
      |> Map.take([:load, :actor, :tenant])
      |> Map.put(:domain, task.domain)
      |> Enum.to_list()

    Ash.update(changeset, %{}, opts)
  end

  defp load_record(task, cfg) do
    opts =
      cfg
      |> Map.take([:actor, :tenant])
      |> Map.put(:domain, task.domain)
      |> Map.put(:not_found_error?, true)
      |> Map.put(:authorize_with, :error)
      |> Enum.to_list()

    with {:ok, field} <- identity_or_pk_field(task.resource, cfg) do
      task.resource
      |> Query.new()
      |> Query.for_read(task.read_action.name)
      |> Query.filter_input(%{field => %{"eq" => cfg.positional_arguments.id}})
      |> Ash.read_one(opts)
    end
  end

  defp read_input(record, task, cfg) when cfg.input == :interactive do
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
      record
      |> Changeset.new()

    Mix.shell().info(
      IO.ANSI.format([
        "Updating ",
        :cyan,
        inspect(task.resource),
        :reset,
        " record using the ",
        :cyan,
        to_string(task.action.name),
        :reset,
        " action:\n"
      ])
    )

    with {:ok, changeset} <- prompt_for_inputs(inputs, task, changeset) do
      {:ok, Changeset.for_update(changeset, task.update)}
    end
  end

  defp read_input(record, task, cfg) when cfg.input == :yaml do
    with {:ok, input} <- read_stdin() do
      case YamlElixir.read_from_string(input) do
        {:ok, map} when is_map(map) ->
          changeset =
            record
            |> Changeset.new()
            |> Changeset.for_update(task.action.name, map)

          {:ok, changeset}

        {:ok, _other} ->
          {:error, "YAML input must be a map"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp read_input(record, task, cfg) when cfg.input == :json do
    with {:ok, input} <- read_stdin() do
      case Jason.decode(input) do
        {:ok, map} when is_map(map) ->
          changeset =
            record
            |> Changeset.new()
            |> Changeset.for_update(task.action, map)

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

      case prompt_for_input(input_name, input_type, task, changeset, entity) do
        {:ok, changeset} -> {:cont, {:ok, changeset}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp prompt_for_input(input_name, input_type, task, changeset, entity, retries \\ 3)

  defp prompt_for_input(input_name, input_type, task, changeset, entity, 0) do
    prompt =
      IO.ANSI.format([
        "Looks like you're having trouble updating the ",
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
    current_value =
      input_changeset
      |> Changeset.get_argument_or_attribute(input_name)
      |> inspect(syntax_colors: IO.ANSI.syntax_colors())
      |> then(&(&1 <> "\n"))

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
      (current_value <> prompt)
      |> Mix.shell().prompt()
      |> String.trim()

    changeset =
      case input_type do
        :attribute -> Changeset.change_attribute(input_changeset, input_name, input)
        :argument -> Changeset.set_argument(input_changeset, input_name, input)
      end

    changeset
    |> Changeset.for_update(task.action)
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
                  |> ArgSchema.add_switch(
                    :input,
                    :string,
                    type: {:custom, AshOps.Task.Types, :atom, [[:json, :yaml, :interactive]]},
                    default: "interactive",
                    required: false,
                    doc:
                      "Read action input from STDIN in this format. Valid options are `json`, `yaml` and `interactive`.  Defaults to `interactive`."
                  )

      @shortdoc "Update a single `#{inspect(@task.resource)}` record using the `#{@task.action.name}` action"

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

      Matching records are updated using input provided as YAML or JSON on
      STDIN or interactively.

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
