# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

defmodule AshOps.Task.CreateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  setup do
    ansi_enabled? = Application.get_env(:elixir, :ansi_enabled)
    Application.put_env(:elixir, :ansi_enabled, false)

    on_exit(fn ->
      Application.put_env(:elixir, :ansi_enabled, ansi_enabled?)
    end)

    :ok
  end

  test "records can be created with YAML input" do
    input = %{
      title: Faker.Food.dish(),
      body: Faker.Food.description(),
      slug: Faker.Internet.slug(),
      tenant: Faker.Lorem.word()
    }

    yaml = Enum.map_join(input, "\n", fn {name, value} -> "#{name}: #{value}" end)

    output =
      capture_io(:stdio, yaml, fn ->
        Mix.Task.rerun("ash_ops.example.create_post", ["--input", "yaml"])
      end)

    assert {:ok, output} = YamlElixir.read_from_string(output)
    assert {:ok, post} = Example.get_post(output["id"], authorize?: false)

    for {key, value} <- input do
      assert Map.fetch!(post, key) == value
    end
  end

  test "records can be created with JSON input" do
    input = %{
      title: Faker.Food.dish(),
      body: Faker.Food.description(),
      slug: Faker.Internet.slug(),
      tenant: Faker.Lorem.word()
    }

    json = Jason.encode!(input)

    output =
      capture_io(:stdio, json, fn ->
        Mix.Task.rerun("ash_ops.example.create_post", ["--input", "json", "--format", "json"])
      end)

    assert {:ok, output} = Jason.decode(output)
    assert {:ok, post} = Example.get_post(output["id"], authorize?: false)

    for {key, value} <- input do
      assert Map.fetch!(post, key) == value
    end
  end
end
