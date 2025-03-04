defmodule Example.Post do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    domain: Example,
    authorizers: [Ash.Policy.Authorizer]

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
    attribute :tenant, :string, allow_nil?: true, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  calculations do
    calculate :length, :integer, expr(string_length(body)), public?: true
    calculate :long, :boolean, expr(length > 10), public?: true
  end

  ets do
    table :posts
    private? true
  end

  identities do
    identity :unique_slug, [:slug], pre_check_with: :read
  end

  multitenancy do
    strategy :attribute
    attribute :tenant
    global? true
  end

  policies do
    policy actor_present() do
      authorize_if actor_attribute_equals(:is_good, true)
    end

    policy always() do
      authorize_if always()
    end
  end

  relationships do
    belongs_to :author, Example.Actor, public?: true
  end
end
