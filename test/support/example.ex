# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Example do
  @moduledoc false
  use Ash.Domain, otp_app: :ash_ops, extensions: [AshOps]

  mix_tasks do
    action __MODULE__.Post, :publish_post, :publish, arguments: [:id, :platform]
    get __MODULE__.Post, :get_post, :read
    list __MODULE__.Post, :list_posts, :read
    create __MODULE__.Post, :create_post, :create
    destroy __MODULE__.Post, :destroy_post, :destroy
    update __MODULE__.Post, :update_post, :update
  end

  resources do
    resource __MODULE__.Actor do
      define :create_actor, action: :create
    end

    resource __MODULE__.Post do
      define :create_post, action: :create
      define :update_post, action: :update
      define :get_post, action: :read, get_by: [:id]
    end
  end
end
