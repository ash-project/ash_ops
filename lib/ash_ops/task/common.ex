defmodule AshOps.Task.Common do
  @moduledoc """
  Common behaviour for all tasks.
  """
  alias Ash.{Query, Resource.Info}
  require Query

  @doc """
  Given a tuple containing a resource and a filter statement, use it to load the
  actor.
  """
  @spec load_actor(nil | {Ash.Resource.t(), String.t()}, String.t()) ::
          {:ok, nil | Ash.Resource.record()} | {:error, any}
  def load_actor(nil, _tenant), do: {:ok, nil}

  def load_actor({resource, filter}, tenant) do
    resource
    |> Query.new()
    |> Query.filter_input(filter)
    |> Ash.read_one(authorize?: false, tenant: tenant)
  end

  @doc """
  Format an error for display and exit with a non-zero status.
  """
  @spec handle_error({:error, any}) :: no_return
  def handle_error({:error, reason}) when is_exception(reason) do
    reason
    |> Exception.message()
    |> Mix.shell().error()

    stop()
  end

  def handle_error({:error, reason}) when is_binary(reason) do
    reason
    |> Mix.shell().error()

    stop()
  end

  def handle_error({:error, reason}) do
    reason
    |> inspect()
    |> Mix.shell().error()

    stop()
  end

  @doc "Serialise the record for display"
  def serialise_record(record, task, cfg) do
    record
    |> filter_record(task, cfg)
    |> format_record(cfg[:format] || :yaml)
  end

  @doc "Serialise a list of records for display"
  def serialise_records(records, task, cfg) when cfg.format == :yaml do
    with {:ok, outputs} <-
           Enum.reduce_while(records, {:ok, []}, fn record, {:ok, outputs} ->
             case serialise_record(record, task, cfg) do
               {:ok, output} -> {:cont, {:ok, [output | outputs]}}
               {:error, reason} -> {:halt, {:error, reason}}
             end
           end) do
      outputs =
        outputs
        |> Enum.reverse()
        |> Enum.join("---\n")

      {:ok, outputs}
    end
  end

  def serialise_records(records, task, cfg) when cfg.format == :json do
    records
    |> Enum.map(&filter_record(&1, task, cfg))
    |> Jason.encode(pretty: true)
  end

  def serialise_records(records, task, cfg),
    do: serialise_records(records, task, Map.put(cfg, :format, :yaml))

  @doc "Return the filter field for the configured identity, or the primary key"
  def identity_or_pk_field(task, cfg) when is_atom(cfg.identity) and not is_nil(cfg.identity) do
    case Info.identity(task.resource, cfg.identity) do
      %{keys: [field]} -> {:ok, field}
      _ -> {:error, "Composite identity error"}
    end
  end

  def identity_or_pk_field(task, _cfg) do
    case Info.primary_key(task.resource) do
      [pk] -> {:ok, pk}
      _ -> {:error, "Primary key error"}
    end
  end

  defp format_record(record, :yaml) do
    record
    |> Map.new(fn
      {key, nil} -> {key, "nil"}
      {key, value} -> {key, value}
    end)
    |> Ymlr.document()
    |> case do
      {:ok, yaml} -> {:ok, String.replace_leading(yaml, "---\n", "")}
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_record(record, :json) do
    record
    |> Jason.encode(pretty: true)
  end

  defp filter_record(record, task, cfg) do
    task.resource
    |> Info.public_fields()
    |> Enum.map(& &1.name)
    |> Enum.concat(cfg[:load] || [])
    |> do_filter_record(record)
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

  if Mix.env() == :test do
    defp stop, do: :ok
  else
    defp stop, do: System.stop(1)
  end
end
