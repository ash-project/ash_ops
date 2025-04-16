defmodule AshOps.Task.Action do
  @moduledoc """
  Provides the implementation of the `action` mix task.

  This should only ever be called from the mix task itself.
  """
  alias Ash.{ActionInput, Resource.Info}
  alias AshOps.Task.ArgSchema
  import AshOps.Task.Common

  @doc false
  def run(argv, task, arg_schema) do
    with {:ok, cfg} <- ArgSchema.parse(arg_schema, argv),
         {:ok, actor} <- load_actor(cfg[:actor], cfg[:tenant]),
         cfg <- Map.put(cfg, :actor, actor),
         {:ok, result} <- run_action(task, cfg),
         {:ok, result} <- maybe_load(result, task, cfg),
         {:ok, output} <- serialise_result(result, task, cfg) do
      Mix.shell().info(output)

      :ok
    else
      {:error, reason} -> handle_error({:error, reason})
    end
  end

  defp maybe_load(result, task, cfg) do
    if record_or_records?(result) do
      {load, opts} =
        cfg
        |> Map.take([:load, :actor, :tenant])
        |> Map.put(:domain, task.domain)
        |> Keyword.new()
        |> Keyword.pop(:load)

      if load == [] do
        {:ok, result}
      else
        Ash.load(result, load, opts)
      end
    else
      {:ok, result}
    end
  end

  defp record_or_records?([%struct{} | _]) do
    Info.resource?(struct)
  end

  defp record_or_records?(%struct{}) do
    Info.resource?(struct)
  end

  defp record_or_records?(_), do: false

  defp run_action(task, cfg) do
    args =
      cfg
      |> Map.get(:positional_arguments, %{})

    opts =
      cfg
      |> Map.take([:load, :actor, :tenant])
      |> Map.put(:domain, task.domain)
      |> Enum.to_list()

    task.resource
    |> ActionInput.for_action(task.action.name, args)
    |> Ash.run_action(opts)
    |> case do
      :ok -> {:ok, :ok}
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp serialise_result(result, task, cfg) do
    if record_or_records?(result) do
      if is_list(result) do
        serialise_records(result, task, cfg)
      else
        serialise_record(result, task, cfg)
      end
    else
      serialise_generic_result(result, cfg)
    end
  end

  defp serialise_generic_result(result, cfg) when cfg.format == :yaml do
    result
    |> Ymlr.document()
    |> case do
      {:ok, yaml} -> {:ok, String.replace_leading(yaml, "---\n", "")}
      {:error, reason} -> {:error, reason}
    end
  end

  defp serialise_generic_result(result, cfg) when cfg.format == :json do
    result
    |> Jason.encode(pretty: true)
  end

  @doc false
  defmacro __using__(opts) do
    quote generated: true do
      @task unquote(opts[:task])
      @arg_schema ArgSchema.default(@task)

      @shortdoc "Run the `#{@task.action.name}` action on the `#{inspect(@task.resource)}` resource."

      @moduledoc """
      #{@shortdoc}


      #{if @task.description, do: "#{@task.description}\n\n"}
      #{if @task.action.description, do: """
        ## Action

        #{@task.action.description}

        """}
      ## Usage

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
