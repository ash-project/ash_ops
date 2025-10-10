# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

defmodule AshOps.QueryLangTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Ash.{Filter, Query}
  alias AshOps.{Info, QueryLang}
  require Query

  setup do
    task = Info.mix_task!(Example, :get_post)

    query =
      task.resource
      |> Query.new()
      |> Query.for_read(task.action.name)

    {:ok, task: task, query: query}
  end

  describe "literals" do
    test "integer", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length == 123")
      assert parsed == Query.filter_input(query, length: [eq: 123])
    end

    test "negative integer", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length == -123")
      assert parsed == Query.filter_input(query, length: [eq: -123])
    end

    test "float", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length == 123.21")
      assert parsed == Query.filter_input(query, length: [eq: 123.21])
    end

    test "negative float", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length == -123.21")
      assert parsed == Query.filter_input(query, length: [eq: -123.21])
    end

    test "boolean true", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "long == true")
      assert parsed == Query.filter_input(query, long: [eq: true])
    end

    test "boolean false", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "long == false")
      assert parsed == Query.filter_input(query, long: [eq: false])
    end

    test "single tick string", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "title == 'Marty McFly'")
      assert parsed == Query.filter_input(query, title: [eq: "Marty McFly"])
    end

    test "double tick string", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "title == \"Marty McFly\"")
      assert parsed == Query.filter_input(query, title: [eq: "Marty McFly"])
    end
  end

  describe "infix" do
    test "eq", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "title == 'Marty McFly'")
      assert parsed == Query.filter_input(query, title: [eq: "Marty McFly"])
    end

    test "neq", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "title != 'Marty McFly'")
      assert parsed == Query.filter_input(query, title: [not_equals: "Marty McFly"])
    end

    test "gt", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length > 3")
      assert parsed == Query.filter_input(query, length: [gt: 3])
    end

    test "gte", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length >= 3")
      assert parsed == Query.filter_input(query, length: [gte: 3])
    end

    test "lt", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length < 3")
      assert parsed == Query.filter_input(query, length: [lt: 3])
    end

    test "lte", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length <= 3")
      assert parsed == Query.filter_input(query, length: [lte: 3])
    end

    test "in", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "title in ['Marty McFly', 'Doc Brown']")
      assert parsed == Query.filter_input(query, title: [in: ["Marty McFly", "Doc Brown"]])
    end

    test "times", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length * 3")
      assert parsed == Query.filter_input(query, length: [times: 3])
    end

    test "div", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length / 3")
      assert parsed == Query.filter_input(query, length: [div: 3])
    end

    test "plus", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length + 3")
      assert parsed == Query.filter_input(query, length: [plus: 3])
    end

    test "minus", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length - 3")
      assert parsed == Query.filter_input(query, length: [minus: 3])
    end

    test "concat", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "title <> slug")
      assert Enum.all?(Filter.list_refs(parsed), & &1.input?)
      assert inspect(parsed) == inspect(Query.filter(query, title <> slug))
    end
  end

  describe "infix precedence" do
    test "and and or", %{task: task, query: query} do
      assert {:ok, parsed} =
               QueryLang.parse(
                 task,
                 "title == 'Marty McFly' || title == 'Doc Brown' && slug == 'doc-brown'"
               )

      assert Enum.all?(Filter.list_refs(parsed), & &1.input?)

      assert parsed ==
               Query.filter_input(
                 query,
                 or: [
                   [title: [eq: "Marty McFly"]],
                   [title: [eq: "Doc Brown"], slug: "doc-brown"]
                 ]
               )
    end

    test "arithmetic", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "length * 3 + 2 == 6")
      assert inspect(parsed) == inspect(Query.filter(query, length * 3 + 2 == 6))
    end
  end

  describe "functions" do
    test "fragment", %{task: task, query: query} do
      assert {:ok, parsed} = QueryLang.parse(task, "fragment('lower(?)', name) == 'fred'")
      assert inspect(parsed) == inspect(Query.filter(query, fragment("lower(?)", name) == "fred"))
    end
  end
end
