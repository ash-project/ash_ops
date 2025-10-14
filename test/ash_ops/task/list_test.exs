# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Task.ListTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  setup do
    ansi_enabled? = Application.get_env(:elixir, :ansi_enabled)
    Application.put_env(:elixir, :ansi_enabled, false)

    on_exit(fn ->
      Application.put_env(:elixir, :ansi_enabled, ansi_enabled?)
    end)

    posts =
      1..3
      |> Enum.map(fn i ->
        Example.create_post!(%{
          title: "#{i}: #{Faker.Food.dish()}",
          body: Faker.Food.description(),
          slug: Faker.Internet.slug(),
          tenant: Faker.Lorem.word()
        })
      end)

    {:ok, posts: posts}
  end

  test "all records are retrieved by default", %{posts: [post0, post1, post2]} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.list_posts")
      end)

    assert output =~ ~r/id: #{post0.id}\n/m
    assert output =~ ~r/id: #{post1.id}\n/m
    assert output =~ ~r/id: #{post2.id}\n/m
  end

  test "records can be filtered by a filter argument", %{posts: [post0, post1, post2]} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.list_posts", ["--filter", "id == '#{post1.id}'"])
      end)

    refute output =~ ~r/id: #{post0.id}\n/m
    assert output =~ ~r/id: #{post1.id}\n/m
    refute output =~ ~r/id: #{post2.id}\n/m
  end

  test "records can be filtered by a filter on STDIN", %{posts: [post0, post1, post2]} do
    output =
      capture_io(:stdio, "id == '#{post1.id}'", fn ->
        Mix.Task.rerun("ash_ops.example.list_posts", ["--filter-stdin"])
      end)

    refute output =~ ~r/id: #{post0.id}\n/m
    assert output =~ ~r/id: #{post1.id}\n/m
    refute output =~ ~r/id: #{post2.id}\n/m
  end

  test "an offset can be applied", %{posts: [post0, post1, post2]} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.list_posts", ["--offset", "2"])
      end)

    refute output =~ ~r/id: #{post0.id}\n/m
    refute output =~ ~r/id: #{post1.id}\n/m
    assert output =~ ~r/id: #{post2.id}\n/m
  end

  test "a limit can be applied", %{posts: [post0, post1, post2]} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.list_posts", ["--limit", "2"])
      end)

    assert output =~ ~r/id: #{post0.id}\n/m
    assert output =~ ~r/id: #{post1.id}\n/m
    refute output =~ ~r/id: #{post2.id}\n/m
  end

  test "a sort can be applied", %{posts: [post0, post1, post2]} do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.list_posts", ["--sort", "'-title'", "--limit", "1"])
      end)

    refute output =~ ~r/id: #{post0.id}\n/m
    refute output =~ ~r/id: #{post1.id}\n/m
    assert output =~ ~r/id: #{post2.id}\n/m
  end

  test "it can filter by tenant", %{posts: posts} do
    tenant =
      posts
      |> Enum.random()
      |> Map.fetch!(:tenant)

    matching_posts = Enum.filter(posts, &(&1.tenant == tenant))
    non_matching_posts = Enum.filter(posts, &(&1.tenant != tenant))

    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.list_posts", ["--tenant", tenant])
      end)

    for post <- matching_posts do
      assert output =~ ~r/id: #{post.id}\n/m
    end

    for post <- non_matching_posts do
      refute output =~ ~r/id: #{post.id}\n/m
    end
  end

  test "when the provided tenant is invalid, it fails" do
    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.list_posts", ["--tenant", "Marty McFly"])
      end)
      |> String.trim()

    assert output == ""
  end
end
