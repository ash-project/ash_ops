# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Entity.Get do
  @moduledoc """
  The `mix_tasks.get` DSL entity.
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
    :resource,
    :task_name,
    arguments: [],
    type: :get
  ]

  @type t :: %__MODULE__{
          __identifier__: any,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta(),
          action: atom | Ash.Resource.Actions.Read.t(),
          arguments: [atom],
          description: nil | String.t(),
          domain: module,
          identity: nil | false | atom,
          name: atom,
          prefix: atom,
          resource: module,
          task_name: atom,
          type: :get
        }

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :get,
      describe: """
      Generate a mix task which calls a read action and returns a single record
      by primary key or identity.

      ## Example

      Defining the following `get` in your domain:

      ```elixir
      mix_tasks do
        get Post, :get_post, :read
      end
      ```

      Will result in the following mix task being available:

      ```bash
      mix my_app.blog.get_post "01953abc-c4e9-7661-a79a-243b0d982ab7"
      title: Example blog post
      body: This is the example blog post
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
        resource: [
          type: {:spark, Ash.Resource},
          required: true,
          doc: "The resource whose action to use"
        ]
      ]
    }
  end
end
