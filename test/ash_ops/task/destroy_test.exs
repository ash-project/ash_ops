defmodule AshOps.Task.DestroyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  setup do
    ansi_enabled? = Application.get_env(:elixir, :ansi_enabled)
    Application.put_env(:elixir, :ansi_enabled, false)

    on_exit(fn ->
      Application.put_env(:elixir, :ansi_enabled, ansi_enabled?)
    end)

    post =
      Example.create_post!(%{
        title: Faker.Food.dish(),
        body: Faker.Food.description(),
        slug: Faker.Internet.slug(),
        tenant: Faker.Lorem.word()
      })

    {:ok, post: post}
  end

  test "it destroys the record", %{post: post} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.destroy_post", [to_string(post.id)])
      end)

    assert output == ""
    assert {:error, error} = Ash.reload(post, authorize?: false)
    assert Exception.message(error) =~ "not found"
  end
end
