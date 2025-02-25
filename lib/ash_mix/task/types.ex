defmodule AshMix.Task.Types do
  @moduledoc """
  Custom `Spark.Options` types for casting and validating CLI arguments.
  """
  alias Ash.Domain.Info, as: ADI
  alias Ash.Resource.Info, as: ARI
  alias Spark.Dsl.Extension

  @type task :: AshMix.Domain.entity()

  @doc "Custom option type for loading an actor"
  @spec actor(any, task) :: {:ok, Ash.Resource.record()} | {:error, any}
  def actor(input, task) when is_binary(input) do
    input
    |> String.split(":")
    |> case do
      [resource, id] -> parse_actor(task, resource, id)
      _ -> {:error, "Invalid actor"}
    end
  end

  def actor(_, _), do: {:error, "Invalid actor"}

  @doc "Custom option type for an identity"
  @spec identity(any, task) :: {:ok, atom} | {:error, any}
  def identity(identity, task) when is_binary(identity) do
    task.resource
    |> ARI.identities()
    |> Enum.reduce_while(
      {:error, "Resource `#{inspect(task.resource)}` has no identity named `#{identity}`"},
      fn ident, error ->
        if to_string(ident.name) == identity do
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          case ident.keys do
            [_] ->
              {:halt, {:ok, ident.name}}

            _ ->
              {:halt,
               {:error,
                "Identity named `#{identity}` on resource `#{inspect(task.resource)}` contains multiple fields"}}
          end

          {:halt, {:ok, ident.name}}
        else
          {:cont, error}
        end
      end
    )
  end

  def identity(nil, task), do: find_resource_pk(task.resource)

  def identity(identity, _task), do: {:error, "Invalid identity `#{inspect(identity)}`"}

  @doc "Custom option type for positional arguments"
  @spec positional_arguments(any, task, Keyword.t(String.t()), Keyword.t(String.t())) ::
          {:ok, [any]} | {:error, any}
  def positional_arguments(input, task, before_args, after_args) when is_list(input) do
    expected_args =
      before_args
      |> Keyword.keys()
      |> Enum.concat(task.arguments)
      |> Enum.concat(Keyword.keys(after_args))

    expected_arg_count = length(expected_args)

    input_length = length(input)

    if input_length == expected_arg_count do
      args =
        expected_args
        |> Enum.zip(input)
        |> Map.new()

      {:ok, args}
    else
      {:error,
       "Expected #{input_length} positional arguments, but received #{expected_arg_count}"}
    end
  end

  def arguments(input, _task, _extras), do: {:error, "Invalid arguments `#{inspect(input)}`"}

  @doc "Custom option type for format"
  @spec format(any) :: {:ok, :json | :yaml} | {:error, any}
  def format("json"), do: {:ok, :json}
  def format("yaml"), do: {:ok, :yaml}

  @doc "Custom option type for load"
  @spec load(any, task) :: {:ok, [atom]} | {:error, any}
  def load(input, task) when is_binary(input) do
    input
    |> String.split(~r/\s*,\s*/, trim: true)
    |> Enum.map(&String.split(&1, ~r/\s*\.\s*/, trim: true))
    |> build_nested_loads()
    |> validate_nested_loads(task.resource)
  end

  def load(input, _task), do: {:error, "Invalid load `#{inspect(input)}`"}

  defp build_nested_loads(loads, result \\ {[], []})
  defp build_nested_loads([], {l_opts, kw_opts}), do: Enum.concat(l_opts, kw_opts)

  defp build_nested_loads([[field] | loads], {l_opts, kw_opts}) when is_binary(field) do
    build_nested_loads(loads, {[field | l_opts], kw_opts})
  end

  defp build_nested_loads([[field | fields] | loads], {l_opts, kw_opts}) when is_binary(field) do
    nested = build_nested_loads([fields])
    kw_opts = [{field, nested} | kw_opts]
    build_nested_loads(loads, {l_opts, kw_opts})
  end

  defp validate_nested_loads(loads, resource, result \\ {[], []})

  defp validate_nested_loads([], _resource, {l_opts, kw_opts}),
    do: {:ok, Enum.concat(l_opts, kw_opts)}

  defp validate_nested_loads([field | loads], resource, {l_opts, kw_opts})
       when is_binary(field) do
    case ARI.public_field(resource, field) do
      nil ->
        {:error,
         "Field `#{field}` does not exist on the `#{inspect(resource)}` resource or is not public"}

      field ->
        validate_nested_loads(loads, resource, {[field.name | l_opts], kw_opts})
    end
  end

  defp validate_nested_loads([{field, fields} | loads], resource, {l_opts, kw_opts}) do
    case ARI.public_relationship(resource, field) do
      nil ->
        {:error,
         "Relationship `#{field}` does not exist on the `#{inspect(resource)}` resource or is not public"}

      rel ->
        with {:ok, nested} <- validate_nested_loads(fields, rel.destination) do
          kw_opts = Keyword.put(kw_opts, rel.name, nested)
          validate_nested_loads(loads, resource, {l_opts, kw_opts})
        end
    end
  end

  defp parse_actor(task, resource, id) do
    with {:ok, otp_app} <- otp_app(task),
         {:ok, resource} <- find_resource(otp_app, resource),
         {:ok, pk} <- find_resource_pk(resource) do
      {:ok, {resource, %{pk => %{"eq" => id}}}}
    end
  end

  defp find_resource(otp_app, resource) when is_binary(resource) do
    otp_app
    |> Application.get_env(:ash_domains, [])
    |> Stream.flat_map(&ADI.resources/1)
    |> Enum.reduce_while(
      {:error, "Unable to find a resource named `#{inspect(resource)}`"},
      fn found, error ->
        if inspect(found) == resource do
          {:halt, {:ok, found}}
        else
          {:cont, error}
        end
      end
    )
  end

  defp find_resource_pk(resource) do
    case ARI.primary_key(resource) do
      [] -> {:error, "The resource `#{inspect(resource)}` has no primary key configured."}
      [pk] -> {:ok, pk}
      _ -> {:error, "The resource `#{inspect(resource)}` has a composite primary key."}
    end
  end

  defp otp_app(task) do
    case Extension.get_persisted(task.domain, :otp_app) do
      nil -> {:error, "otp_app option is missing from `#{inspect(task.domain)}` domain"}
      domain -> {:ok, domain}
    end
  end
end
