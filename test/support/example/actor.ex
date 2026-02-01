# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Example.Actor do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    domain: Example

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :is_good, :boolean, allow_nil?: false, public?: true
  end

  ets do
    table :actor
    private? true
  end
end
