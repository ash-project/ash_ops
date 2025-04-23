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

  @doc "Return the filter field for the configured identity, or the primary key"
  def identity_or_pk_field(resource, cfg)
      when is_atom(cfg.identity) and not is_nil(cfg.identity) do
    case Info.identity(resource, cfg.identity) do
      %{keys: [field]} -> {:ok, field}
      _ -> {:error, "Composite identity error"}
    end
  end

  def identity_or_pk_field(resource, _cfg) do
    case Info.primary_key(resource) do
      [pk] -> {:ok, pk}
      _ -> {:error, "Primary key error"}
    end
  end

  @doc "Serialise the record for display"
  def serialise_record(record, resource, cfg) do
    data = prepare_record(record, resource, cfg)

    case cfg.format do
      :yaml ->
        data
        |> Ymlr.document()
        |> case do
          {:ok, yaml} -> {:ok, String.replace_leading(yaml, "---\n", "")}
          {:error, reason} -> {:error, reason}
        end

      :json ->
        data
        |> Jason.encode(pretty: true)
    end
  end

  @doc "Serialise a list of records for display"
  def serialise_records(records, resource, cfg) when cfg.format == :yaml do
    with {:ok, outputs} <-
           Enum.reduce_while(records, {:ok, []}, fn record, {:ok, outputs} ->
             case serialise_record(record, resource, cfg) do
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

  def serialise_records(records, resource, cfg) when cfg.format == :json do
    records
    |> Enum.map(&prepare_record(&1, resource, cfg))
    |> Jason.encode(pretty: true)
  end

  def serialise_records(records, resource, cfg),
    do: serialise_records(records, resource, Map.put(cfg, :format, :yaml))

  # Filter and format record fields, but do not encode
  defp prepare_record(record, resource, cfg) do
    record
    |> filter_record(resource, cfg)
    |> format_record(resource, cfg)
  end

  # Apply formatting to each field of a filtered record
  defp format_record(record, resource, cfg) do
    Map.new(record, fn
      {key, value} ->
        field_info = resource |> Info.field(key)
        {key, format_value(value, field_info, cfg)}
    end)
  end

  @doc """
  Format a value given the field type info and formatting configuration options
  """
  def format_value(value, field_info, cfg)

  # NOTE: In future, dispatch on the type, not the value to support new types
  def format_value(value = %Ash.CiString{}, field_info, cfg) do
    format_value(to_string(value), field_info, cfg)
  end

  def format_value(nil, _field, %{format: :yaml}) do
    "nil"
  end

  def format_value(value, attribute = %{type: {:array, type}}, cfg) when is_list(value) do
    inner_type = type
    inner_constraints = attribute.constraints[:items] || []
    inner_attribute = %{attribute | type: inner_type, constraints: inner_constraints}
    Enum.map(value, &format_value(&1, inner_attribute, cfg))
  end

  # HasMany or ManyToMany relationships
  def format_value(value, attribute = %{cardinality: :many}, cfg) when is_list(value) do
    Enum.map(value, &format_value(&1, attribute, cfg))
  end

  def format_value(%struct{} = value, field_info, cfg) do
    if Info.resource?(struct) do
      load = cfg[:load][field_info.name] || []
      cfg = Map.put(cfg, :load, load)
      prepare_record(value, struct, cfg)
    else
      format_fallback_value(value, cfg)
    end
  end

  def format_value(value, _field_info, cfg) do
    format_fallback_value(value, cfg)
  end

  defp format_fallback_value(value, %{format: :json}) do
    if Jason.Encoder.impl_for(value) do
      value
    else
      "<Failed to encode>"
    end
  end

  defp format_fallback_value(value, %{format: :yaml}) do
    if Ymlr.Encoder.impl_for(value) do
      value
    else
      "<Failed to encode>"
    end
  end

  # Convert a record to a plain map, excluding private fields
  defp filter_record(record, _resource, cfg) do
    record
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
