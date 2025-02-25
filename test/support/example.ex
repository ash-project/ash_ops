defmodule Example do
  @moduledoc false
  use Ash.Domain, otp_app: :ash_mix, extensions: [AshMix.Domain]

  mix_tasks do
    get __MODULE__.Post, :get_post, :read
  end

  resources do
    resource __MODULE__.Actor do
      define :create_actor, action: :create
    end

    resource __MODULE__.Post do
      define :create_post, action: :create
      define :update_post, action: :update
    end
  end
end
