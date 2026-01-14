# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Entity.Destroy do
  @moduledoc """
  The `mix_tasks.destroy` DSL entity.
  """

  defstruct [
    :__identifier__,
    :__spark_metadata__,
    :action,
    :description,
    :domain,
    :identity,
    :name,
    :prefix,
    :read_action,
    :resource,
    :task_name,
    arguments: [],
    type: :destroy
  ]

  @type t :: %__MODULE__{
          __identifier__: any,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta(),
          action: atom | Ash.Resource.Actions.Destroy.t(),
          arguments: [atom],
          description: nil | String.t(),
          domain: module,
          identity: nil | false | atom,
          name: atom,
          prefix: atom,
          read_action: nil | atom | Ash.Resource.Actions.Read.t(),
          resource: module,
          task_name: atom,
          type: :destroy
        }

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :destroy,
      describe: """
      Generate a mix task which calls a destroy action and removes a single record
      by primary key or identity.

      ## Example

      Defining the following `destroy` in your domain:

      ```elixir
      mix_tasks do
        destroy Post, :destroy_post, :destroy
      end
      ```

      Will result in the following mix task being available:

      ```bash
      mix my_app.blog.destroy_post "01953abc-c4e9-7661-a79a-243b0d982ab7"
      status: ok
      ```
      """,
      target: __MODULE__,
      identifier: :name,
      args: [:resource, :name, :action],
      schema: [
        action: [
          type: :atom,
          required: true,
          doc: "The name of the destroy action to use"
        ],
        arguments: [
          type: {:wrap_list, :atom},
          required: false,
          default: [],
          doc:
            "A list of action arguments which should be taken as positional arguments on the command line"
        ],
        description: [
          type: :string,
          required: false,
          doc: "Documentation to be displayed in the mix task's help section"
        ],
        identity: [
          type: {:or, [:atom, {:literal, false}]},
          required: false,
          doc:
            "The identity to use for looking up the record. Use `false` to skip adding identity arguments."
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
        read_action: [
          type: :atom,
          required: false,
          doc:
            "The read action to use to query for matching records to destroy. Defaults to the primary read action."
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
