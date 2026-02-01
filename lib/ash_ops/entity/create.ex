# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Entity.Create do
  @moduledoc """
  The `mix_tasks.create` DSL entity.
  """

  defstruct [
    :__identifier__,
    :__spark_metadata__,
    :action,
    :description,
    :domain,
    :name,
    :prefix,
    :resource,
    :task_name,
    arguments: [],
    type: :create
  ]

  @type t :: %__MODULE__{
          __identifier__: any,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta(),
          action: atom | Ash.Resource.Actions.Create.t(),
          arguments: [],
          description: nil | String.t(),
          domain: module,
          name: atom,
          prefix: atom,
          resource: module,
          task_name: atom,
          type: :create
        }

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :create,
      describe: """
      Generate a mix task which calls a create action and returns the created
      record.

      ## Example

      Defining the following `create` in your domain:

      ```elixir
      mix_tasks do
        create Post, :create_post, :create
      end
      ```

      Will result in the following mix task being available:

      ```bash
      mix my_app.blog.create_post
      ```
      """,
      target: __MODULE__,
      identifier: :name,
      args: [:resource, :name, :action],
      schema: [
        action: [
          type: :atom,
          required: true,
          doc: "The name of the create action to use"
        ],
        description: [
          type: :string,
          required: false,
          doc: "Documentation to be displayed in the mix task's help section"
        ],
        name: [
          type: :atom,
          required: true,
          doc: "The name of the mix task to generate"
        ],
        prefix: [
          type: :atom,
          required: false,
          doc:
            "The prefix to use for the mix task name (ie the part before the first \".\"). Defaults to the `otp_app` setting of the domain"
        ],
        resource: [
          type: {:spark, Ash.Resource},
          required: true,
          doc: "The resource whose actions to use"
        ]
      ]
    }
  end
end
