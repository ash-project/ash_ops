defmodule AshOps.Transformer.SetTaskName do
  @moduledoc """
  A Spark DSL transformer which computes and caches the mix task names.
  """
  use Spark.Dsl.Transformer
  import Spark.Dsl.Transformer

  alias Ash.Resource.Info, as: ARI
  alias AshOps.Info, as: AOI

  @doc false
  @impl true
  def after?(_), do: true

  @doc false
  @impl true
  def transform(dsl) do
    dsl
    |> AOI.mix_tasks()
    |> Enum.reduce({:ok, dsl}, fn entity, {:ok, dsl} ->
      domain =
        entity.resource
        |> ARI.domain()
        |> Module.split()
        |> List.last()
        |> Macro.underscore()

      entity = %{entity | task_name: "#{entity.prefix}.#{domain}.#{entity.name}"}

      {:ok, replace_entity(dsl, [:mix_tasks], entity)}
    end)
  end
end
