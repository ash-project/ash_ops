# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Task.UpdateTest do
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

  test "it can update the record with YAML", %{post: post} do
    body =
      post.body
      |> String.replace(~r/[aeiou]/i, "")

    yaml = "body: \"#{body}\"\n"

    output =
      capture_io(:stdio, yaml, fn ->
        Mix.Task.rerun("ash_ops.example.update_post", [post.id, "--input", "yaml"])
      end)

    assert {:ok, output} = YamlElixir.read_from_string(output)
    assert {:ok, post} = Example.get_post(output["id"], authorize?: false)
    assert post.body == body
  end

  test "it can update the record with JSON", %{post: post} do
    body =
      post.body
      |> String.replace(~r/[aeiou]/i, "")

    json = Jason.encode!(%{body: body})

    output =
      capture_io(:stdio, json, fn ->
        Mix.Task.rerun("ash_ops.example.update_post", [
          post.id,
          "--input",
          "json",
          "--format",
          "json"
        ])
      end)

    assert {:ok, output} = Jason.decode(output)
    assert {:ok, post} = Example.get_post(output["id"], authorize?: false)
    assert post.body == body
  end
end
