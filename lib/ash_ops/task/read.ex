defmodule AshOps.Task.Read do
  @moduledoc """
  Common behaviour for both `get` and `list`` tasks.
  """
  alias Ash.Query
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

  if Mix.env() == :test do
    def stop, do: :ok
  else
    def stop, do: System.stop(1)
  end
end
