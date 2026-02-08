# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Entity.List do
  @moduledoc """
  The `mix_tasks.list` DSL entity.
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
    type: :list
  ]

  @type t :: %__MODULE__{
          __identifier__: any,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta(),
          action: atom | Ash.Resource.Actions.Read.t(),
          arguments: [atom],
          description: nil | String.t(),
          domain: module,
          name: atom,
          prefix: atom,
          resource: module,
          task_name: atom,
          type: :list
        }

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :list,
      describe: """
      Generate a mix task which calls a read action and returns any matching records.

      ## Example

      Define the following `list` in your domain:application

      ```elixir
      mix_tasks do
        list Post, :list_posts, :read
      end
      ```

      Will result in the following mix task being available:application

      ```bash
      mix my_app.blog.list_posts
      ```
      """,
      target: __MODULE__,
      identifier: :name,
      args: [:resource, :name, :action],
      schema: [
        action: [
          type: :atom,
          required: true,
          doc: "The name of the read action to use"
        ],
        arguments: [
          type: {:wrap_list, :atom},
          required: false,
          doc:
            "A comma-separated list of action arguments can be taken as positional arguments on the command line"
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
            "The prefix to use for the mix task name (ie the part before the first \".\").  Defaults to the `otp_app` setting of the domain"
        ],
        resource: [
          type: {:spark, Ash.Resource},
          required: true,
          doc: "The resource whose action to use"
        ]
      ]
    }
  end
end
