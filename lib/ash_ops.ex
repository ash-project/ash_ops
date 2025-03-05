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
        action Post, :publish_post, :publish
        create Post, :create_post, :create
        destroy Post, :destroy_post, :destroy
        get Post, :get_post, :read
        list Post, :list_posts, :read
        update Post, :update_post, :update
      end
      """
    ],
    entities: [
      __MODULE__.Entity.Action.__entity__(),
      __MODULE__.Entity.Create.__entity__(),
      __MODULE__.Entity.Destroy.__entity__(),
      __MODULE__.Entity.Get.__entity__(),
      __MODULE__.Entity.List.__entity__(),
      __MODULE__.Entity.Update.__entity__()
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@mix_tasks],
    transformers: [__MODULE__.Transformer.PrepareTask],
    verifiers: [__MODULE__.Verifier.VerifyTask]

  @type entity ::
          __MODULE__.Entity.Action.t()
          | __MODULE__.Entity.Create.t()
          | __MODULE__.Entity.Destroy.t()
          | __MODULE__.Entity.Get.t()
          | __MODULE__.Entity.List.t()
          | __MODULE__.Entity.Update.t()
end
