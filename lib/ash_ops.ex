defmodule AshOps do
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
        list Post, :list_posts, :read
        create Post, :create_post, :create
      end
      """
    ],
    entities: [
      __MODULE__.Entity.Create.__entity__(),
      __MODULE__.Entity.Get.__entity__(),
      __MODULE__.Entity.List.__entity__()
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@mix_tasks],
    transformers: [__MODULE__.Transformer.PrepareTask],
    verifiers: [__MODULE__.Verifier.VerifyTask]

  @type entity ::
          __MODULE__.Entity.Create.t()
          | __MODULE__.Entity.Get.t()
          | __MODULE__.Entity.List.t()
end
