# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Task.GetTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Ash.Resource.Info
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

  test "it can be retrieved by it's public key", %{post: post} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [to_string(post.id)])
      end)

    assert output =~ ~r/id: #{post.id}/m
  end

  test "it displays public attributes by default", %{post: post} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [to_string(post.id)])
      end)

    public_attributes =
      Example.Post
      |> Info.public_attributes()
      |> Enum.map(& &1.name)

    for field <- public_attributes do
      value =
        post
        |> Map.fetch!(field)
        |> to_string()
        |> Regex.escape()

      assert output =~ ~r/#{field}: #{value}/m
    end
  end

  test "it can use a provided tenant", %{post: post} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.get_post", ["--tenant", post.tenant, to_string(post.id)])
      end)

    assert output =~ ~r/id: #{post.id}/m
  end

  test "when the provided tenant is invalid, it fails", %{post: post} do
    output =
      capture_io(:stderr, fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [
          "--tenant",
          "Marty McFly",
          to_string(post.id)
        ])
      end)

    assert output =~ ~r/not found/im
  end

  test "it can format the output as JSON", %{post: post} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.get_post", ["--format", "json", to_string(post.id)])
      end)

    assert output =~ ~r/"id": #{inspect(post.id)},/m
  end

  test "it can use an identity to find the record", %{post: post} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [
          "--identity",
          "unique_slug",
          to_string(post.slug)
        ])
      end)

    assert output =~ ~r/id: #{post.id}/m
  end

  test "when an actor is provided and is authorised, it is successful", %{post: post} do
    actor = Example.create_actor!(%{is_good: true})

    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [
          "--actor",
          "Example.Actor:#{actor.id}",
          to_string(post.id)
        ])
      end)

    assert output =~ ~r/id: #{post.id}/m
  end

  test "when the actor is provided and is not authorised, it fails", %{post: post} do
    actor = Example.create_actor!(%{is_good: false})

    output =
      capture_io(:stderr, fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [
          "--actor",
          "Example.Actor:#{actor.id}",
          to_string(post.id)
        ])
      end)

    assert output =~ ~r/forbidden/im
  end

  test "when the post doesn't exist, it fails" do
    output =
      capture_io(:stderr, fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [to_string(Ash.UUID.generate())])
      end)

    assert output =~ ~r/not found/im
  end

  test "calculations can be loaded and returned", %{post: post} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [
          "--load",
          "length",
          to_string(post.id)
        ])
      end)

    assert output =~ ~r/id: #{post.id}/m
    assert output =~ ~r/length: #{byte_size(post.body)}/m
  end

  test "relationships can be loaded and returned", %{post: post} do
    author = Example.create_actor!(%{is_good: false})
    post = Example.update_post!(post, %{author_id: author.id})

    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.get_post", [
          "--load",
          "author.id",
          to_string(post.id)
        ])
      end)

    assert output =~ ~r/id: #{post.id}/m
    assert output =~ ~r/author:\n  id: #{author.id}/m
  end
end
