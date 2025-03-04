defmodule AshOps.Task.ArgSchema do
  @moduledoc """
  A struct which contains information about the arguments a task expects to
  receive.
  """

  defstruct [:op_schema, :so_schema]

  @type t :: %__MODULE__{
          op_schema: OptionParser.options(),
          so_schema: Spark.Options.schema()
        }

  @doc """
  Return the default arguments that all tasks expect to take.
  """
  @spec default(AshOps.entity()) :: t
  def default(task) do
    %__MODULE__{
      op_schema: [
        aliases: [
          a: :actor,
          f: :format,
          l: :load,
          t: :tenant
        ],
        strict: [
          actor: :string,
          format: :string,
          load: :string,
          tenant: :string
        ]
      ],
      so_schema: [
        actor: [
          type: {:custom, AshOps.Task.Types, :actor, [task]},
          required: false,
          doc:
            "Specify the actor to use for the request in the format `resource:id`, eg: `Example.Accounts.User:abc123`."
        ],
        format: [
          type: {:custom, AshOps.Task.Types, :format, []},
          required: false,
          default: "yaml",
          doc: "The output format to display the result in. Either `json` or `yaml`."
        ],
        load: [
          type: {:custom, AshOps.Task.Types, :load, [task]},
          required: false,
          doc:
            "An optional load query as a comma separated list of fields, fields can be nested with dots."
        ],
        tenant: [
          type: :string,
          required: false,
          doc: "Specify a tenant to use when executing the query."
        ],
        positional_arguments: [
          type: {:custom, AshOps.Task.Types, :positional_arguments, [task, [], []]},
          required: true
        ]
      ]
    }
  end

  @doc """
  Prepend a positional argument to the beginning argument list

  ie before any action arguments taken by the task.
  """
  @spec prepend_positional(t, atom, String.t()) :: t
  def prepend_positional(arg_schema, name, help_text) do
    arg_schema
    |> update_positional_args(fn before_args, after_args ->
      {[{name, help_text} | before_args], after_args}
    end)
  end

  @doc """
  Append a positional argument to the end of the argument list

  ie after any action arguments taken by the task.
  """
  @spec append_positional(t, atom, String.t()) :: t
  def append_positional(arg_schema, name, help_text) do
    arg_schema
    |> update_positional_args(fn before_args, after_args ->
      {before_args, Enum.concat(after_args, [{name, help_text}])}
    end)
  end

  @doc """
  Remove a positional argument by name.
  """
  @spec remove_positional(t, atom) :: t
  def remove_positional(arg_schema, name) do
    arg_schema
    |> update_positional_args(fn before_args, after_args ->
      {Keyword.delete(before_args, name), Keyword.delete(after_args, name)}
    end)
  end

  @doc """
  Add a switch to the arguments

  ## Arguments

  - `name` the name of the switch - this will be dasherised by `OptionParser`.
  - `op_type` the type to cast the argument to (as per `OptionParser.parse/2`).
  - `so_type` the `Spark.Options` type for to validate the resulting input.
  - `help_text` the text to display when asked to render usage information.
  - `aliases` a list of "short name" aliases for the switch.
  """
  @spec add_switch(t, atom, atom, any, String.t(), [atom]) :: t
  def add_switch(arg_schema, name, op_type, so_type, help_text, aliases \\ []) do
    arg_schema
    |> Map.update!(:op_schema, fn schema ->
      schema
      |> Keyword.update!(:strict, &Keyword.put(&1, name, op_type))
      |> Keyword.update!(:aliases, fn existing_aliases ->
        aliases
        |> Enum.reduce(existing_aliases, &Keyword.put(&2, &1, name))
      end)
    end)
    |> Map.update!(:so_schema, fn schema ->
      schema
      |> Keyword.put(name,
        type: so_type,
        required: false,
        doc: help_text
      )
    end)
  end

  @doc """
  Remove a switch from the argument schemas
  """
  @spec remove_switch(t, atom) :: t
  def remove_switch(arg_schema, name) do
    arg_schema
    |> Map.update!(:op_schema, fn schema ->
      schema
      |> Keyword.update!(:strict, &Keyword.delete(&1, name))
      |> Keyword.update!(:aliases, fn aliases ->
        Enum.reject(aliases, &(elem(&1, 1) == name))
      end)
    end)
    |> Map.update!(:so_schema, &Keyword.delete(&1, name))
  end

  defp update_positional_args(arg_schema, updater) when is_function(updater, 2) do
    arg_schema
    |> Map.update!(:so_schema, fn schema ->
      schema
      |> Keyword.update!(:positional_arguments, fn positional_arguments ->
        positional_arguments
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        |> Keyword.update!(:type, fn {:custom, AshOps.Task.Types, :positional_arguments,
                                      [task, before_args, after_args]} ->
          {before_args, after_args} = updater.(before_args, after_args)
          {:custom, AshOps.Task.Types, :positional_arguments, [task, before_args, after_args]}
        end)
      end)
    end)
  end

  @doc """
  Parse and validate the command-line arguments.
  """
  @spec parse(t, OptionParser.argv()) :: {:ok, %{atom => any}} | {:error, any}
  def parse(arg_schema, argv) do
    with {:ok, parsed} <- parse_args(argv, arg_schema.op_schema),
         {:ok, valid} <- Spark.Options.validate(parsed, arg_schema.so_schema) do
      {:ok, Map.new(valid)}
    end
  end

  @doc """
  Display usage information about the arguments
  """
  @spec usage(AshOps.entity(), t) :: String.t()
  def usage(task, arg_schema) do
    [
      """
      ## Example

      ```bash
      #{example_usage(task, arg_schema)}
      ```
      """,
      if has_positional_args?(arg_schema) do
        """

        ## Command line arguments

        #{positional_argument_usage(arg_schema)}
        """
      end,
      if has_switches?(arg_schema) do
        """

        ## Command line options

        #{switch_usage(arg_schema)}
        """
      end
    ]
    |> Enum.map_join("\n", &to_string/1)
  end

  defp has_positional_args?(arg_schema) do
    arg_schema.so_schema
    |> Keyword.get(:positional_arguments, [])
    |> Keyword.get(:type, {:custom, AshOps.Task.Types, :positional_arguments, [nil, [], []]})
    |> elem(3)
    |> Enum.drop(1)
    |> Enum.concat()
    |> Enum.any?()
  end

  defp has_switches?(arg_schema) do
    arg_schema.so_schema
    |> Keyword.delete(:positional_arguments)
    |> Enum.any?()
  end

  defp example_usage(task, arg_schema) do
    underscored_domain =
      task.domain
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    positional_args =
      arg_schema
      |> extract_positional_args()
      |> Enum.map(fn {name, _} ->
        name
        |> to_string()
        |> String.upcase()
      end)

    ["mix #{task.prefix}.#{underscored_domain}.#{task.name}" | positional_args]
    |> Enum.join(" ")
  end

  defp extract_positional_args(arg_schema) do
    {:custom, AshOps.Task.Types, :positional_arguments, [task, before_args, after_args]} =
      arg_schema
      |> Map.fetch!(:so_schema)
      |> Keyword.fetch!(:positional_arguments)
      |> Keyword.fetch!(:type)

    mid_args =
      task.arguments
      |> Enum.map(fn arg ->
        task.action.arguments
        |> Enum.find_value("Argument to the `#{task.action.name}` action", fn action_arg ->
          action_arg.name == arg && action_arg.description
        end)
      end)

    before_args
    |> Enum.concat(mid_args)
    |> Enum.concat(after_args)
  end

  defp positional_argument_usage(arg_schema) do
    arg_schema
    |> extract_positional_args()
    |> Enum.map_join("\n", fn {name, description} ->
      name =
        name
        |> to_string()
        |> String.upcase()

      "  * `#{name}` - #{description}"
    end)
  end

  defp switch_usage(arg_schema) do
    arg_schema.op_schema
    |> Keyword.fetch!(:strict)
    |> Enum.map_join("\n", fn
      {name, type} ->
        underscored =
          name
          |> to_string()
          |> String.replace("_", "-")

        aliases =
          arg_schema.op_schema
          |> Keyword.fetch!(:aliases)
          |> Enum.filter(&(elem(&1, 1) == name))
          |> Enum.map(&"`-#{elem(&1, 0)}`")

        aliases =
          if type == :boolean do
            ["`--no-#{underscored}`" | aliases]
          else
            aliases
          end

        aliases =
          if Enum.any?(aliases) do
            "(#{Enum.join(aliases, ", ")}) "
          end

        help_text =
          arg_schema.so_schema
          |> Keyword.fetch!(name)
          |> Keyword.fetch!(:doc)

        "  * `--#{underscored}` #{aliases}- #{help_text}"
    end)
  end

  defp parse_args(argv, op_schema) do
    case OptionParser.parse(argv, op_schema) do
      {parsed, argv, []} ->
        args =
          parsed
          |> Keyword.put(:positional_arguments, argv)

        {:ok, args}

      {_, _, errors} ->
        {:error, "Unable to parse arguments: `#{inspect(errors)}`"}
    end
  end
end
