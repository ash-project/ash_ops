# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Entity.Update do
  @moduledoc """
  The `mix_tasks.update` DSL entity.
  """

  defstruct [
    :__identifier__,
    :__spark_metadata__,
    :action,
    :description,
    :domain,
    :name,
    :prefix,
    :read_action,
    :resource,
    :task_name,
    arguments: [],
    type: :update
  ]

  @type t :: %__MODULE__{
          __identifier__: any,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta(),
          action: atom | Ash.Resource.Actions.Update.t(),
          arguments: [atom],
          description: nil | String.t(),
          domain: module,
          name: atom,
          prefix: atom,
          read_action: nil | atom | Ash.Resource.Actions.Read.t(),
          resource: module,
          task_name: atom,
          type: :update
        }

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :update,
      describe: """
      Generate a mix task which calls an update action and updates a single record
      by primary key or identity.

      ## Example

      Defining the following `update` in your domain:

      ```elixir
      mix_tasks do
        update Post, :update_post, :update
      end
      ```

      Will result in the following mix task being available:

      ```bash
      mix my_app.blog.update_post "01953abc-c4e9-7661-a79a-243b0d982ab7"
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
            "The read action to use to query for matching records to update. Defaults to the primary read action."
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
