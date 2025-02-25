defmodule AshMix.Domain do
  @moduledoc """
  An extension for `Ash.Domain` that adds the ability expose resource actions as
  mix tasks.
  """

  @mix_tasks %Spark.Dsl.Section{
    name: :mix_tasks,
    describe: """
    Resource actions to expose as mix tasks.
    """,
    examples: [
      """
      mix_tasks do
        get Post, :get_post, :read
      end
      """
    ],
    entities: [
      __MODULE__.Entity.Get.__entity__()
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@mix_tasks],
    transformers: [__MODULE__.Transformer.Get],
    verifiers: [__MODULE__.Verifier.Get]

  @type entity :: __MODULE__.Entity.Get.t()
end
