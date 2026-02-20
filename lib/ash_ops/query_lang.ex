# SPDX-FileCopyrightText: 2025 ash_ops contributors <https://github.com/ash-project/ash_ops/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOps.QueryLang do
  @langdoc """
  The Ash Ops query language is very similar to the
  [Ash expression syntax](https://hexdocs.pm/ash/expressions.html)
  while not actually being Elixir.

  ### Literals

  - `true` and `false` boolean literals.
  - Integer literals, eg `123`, `-123` and `0`.
  - Float literals, of the form `1.23` and `-1.23` (ie not scientific notation).
  - String literals of delimited with both single ticks (`'`) and double ticks
    (`"`) are interpreted as Elixir binaries.
  - Attribute path literals are entered directly, separated by `.` as necessary.

  ### Infix operators

  The following infix operators (and their aliases) are available:

  - `&&` and `and`,
  - `||` and `or`,
  - `*` and `times`,
  - `/` and `div`,
  - `+` and `plus`,
  - `-` and `minus`,
  - `<>` and `concat`,
  - `in`,
  - `>` and `gt`,
  - `>=` and `gte`,
  - `<` and `lt`,
  - `<=` and `lte`,
  - `==` and `eq`,
  - `!=` and `not_eq`.

  ### Function calls

  Function calls of the form `function(arg, arg)` format are allowed.  The
  functions available are highly dependant on the extensions and data layer
  being used by the resource being queried.
  """

  @moduledoc """
  The query language for simple queries entered on the command-line.

  This query language is not capable of expressing the full breadth of the Ash
  expression language.  It is designed to provide a simple subset of filters
  available to users of AshOps. If you need something more advanced then it's
  probably a good idea to make a special read query filtered in the way you
  require and expose that as a mix task instead.

  ## Syntax

  #{@langdoc}
  """
  alias Ash.{Query, Query.BooleanExpression, Query.Call, Query.Operator, Query.Ref}
  require Query

  @doc """
  Parse a query and return a compiled `Ash.Query` struct.
  """
  @spec parse(AshOps.entity(), nil | String.t()) :: {:ok, Ash.Query.t()} | {:error, any}
  def parse(task, nil), do: {:ok, base_query(task)}

  def parse(task, query) do
    with {:ok, query} <- do_parse(query) do
      query
      |> precedence()
      |> compile(task)
    end
  end

  @doc false
  def doc, do: @langdoc

  defp base_query(task) do
    task.resource
    |> Query.new()
    |> Query.for_read(task.action.name)
  end

  defp do_parse(query) do
    query
    |> :ash_ops_query.parse()
    |> case do
      {:fail, {:expected, _, {{:line, line}, {:column, column}}}} ->
        {:error, "Unable to parse query at #{line}:#{column}"}

      {:fail, _} ->
        {:error, "Unable to parse query."}

      {_parsed, unparsed} ->
        {:error, "Unable to parse query: unexpected input `#{unparsed}`."}

      {_parsed, unparsed, {{:line, line}, {:column, column}}} ->
        {:error, "Unable to parse query: unexpected input `#{unparsed}` at #{line}:#{column}"}

      parsed when is_list(parsed) ->
        {:ok, parsed}
    end
  end

  defp precedence([lhs | rest]), do: do_prec(lhs, rest, 0)

  defp do_prec(lhs, [], _min_prec), do: lhs

  defp do_prec(lhs, [{:op, op, _, prec0}, rhs, {:op, _, assoc1, prec1} = op1 | rest], min_prec)
       when prec0 >= min_prec and
              ((assoc1 == :left and prec1 > prec0) or (assoc1 == :right and prec1 >= prec0)) do
    next_min_prec = if prec1 > prec0, do: prec0 + 1, else: prec0
    rhs = do_prec(rhs, [op1 | rest], next_min_prec)
    do_prec({:op, op, lhs, rhs}, [], min_prec)
  end

  defp do_prec(lhs, [{:op, op, _, _}, rhs | rest], min_prec) do
    do_prec({:op, op, lhs, rhs}, rest, min_prec)
  end

  defp compile(query, task) do
    with {:ok, filter} <- to_filter(query) do
      query =
        task
        |> base_query()
        |> Query.do_filter(filter)

      {:ok, query}
    end
  end

  defp to_filter({:op, :&&, lhs, rhs}) do
    with {:ok, lhs} <- to_filter(lhs),
         {:ok, rhs} <- to_filter(rhs) do
      {:ok, BooleanExpression.new(:and, lhs, rhs)}
    end
  end

  defp to_filter({:op, :||, lhs, rhs}) do
    with {:ok, lhs} <- to_filter(lhs),
         {:ok, rhs} <- to_filter(rhs) do
      {:ok, BooleanExpression.new(:or, lhs, rhs)}
    end
  end

  defp to_filter({:op, op, lhs, rhs}) do
    with {:ok, module} <- op_to_module(op),
         {:ok, lhs} <- to_filter(lhs),
         {:ok, rhs} <- to_filter(rhs) do
      Operator.new(module, lhs, rhs)
    end
  end

  defp to_filter({:path, segments}) do
    with {:ok, segments} <-
           segments
           |> map_while(fn
             {:ident, segment} -> {:ok, segment}
             other -> {:error, "Unexpected path segment: `#{inspect(other)}`"}
           end) do
      segments
      |> Enum.reverse()
      |> case do
        [ident] ->
          {:ok, %Ref{attribute: ident, relationship_path: [], input?: true}}

        [ident | rest] ->
          {:ok, %Ref{attribute: ident, relationship_path: Enum.reverse(rest), input?: true}}
      end
    end
  end

  defp to_filter({:function, {:ident, name}, arguments}) do
    with {:ok, arguments} <- map_while(arguments, &to_filter/1) do
      {:ok, %Call{name: name, args: arguments}}
    end
  end

  defp to_filter({:array, array}) do
    map_while(array, &to_filter/1)
  end

  defp to_filter({:string, value}) when is_binary(value), do: {:ok, value}
  defp to_filter({:float, float}) when is_float(float), do: {:ok, float}
  defp to_filter({:boolean, boolean}) when is_boolean(boolean), do: {:ok, boolean}
  defp to_filter({:integer, int}) when is_integer(int), do: {:ok, int}
  defp to_filter(token), do: {:error, "Unexpected token `#{inspect(token)}`"}

  defp op_to_module(:*), do: {:ok, Operator.Basic.Times}
  defp op_to_module(:/), do: {:ok, Operator.Basic.Div}
  defp op_to_module(:+), do: {:ok, Operator.Basic.Plus}
  defp op_to_module(:-), do: {:ok, Operator.Basic.Minus}
  defp op_to_module(:<>), do: {:ok, Operator.Basic.Concat}
  defp op_to_module(:in), do: {:ok, Operator.In}
  defp op_to_module(:>), do: {:ok, Operator.GreaterThan}
  defp op_to_module(:>=), do: {:ok, Operator.GreaterThanOrEqual}
  defp op_to_module(:<), do: {:ok, Operator.LessThan}
  defp op_to_module(:<=), do: {:ok, Operator.LessThanOrEqual}
  defp op_to_module(:==), do: {:ok, Operator.Eq}
  defp op_to_module(:!=), do: {:ok, Operator.NotEq}
  defp op_to_module(op), do: {:error, "Unknown infix operator `#{inspect(op)}`"}

  defp map_while(input, mapper) do
    result =
      Enum.reduce_while(input, {:ok, []}, fn element, {:ok, acc} ->
        case mapper.(element) do
          {:ok, element} -> {:cont, {:ok, [element | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
      {:ok, elements} -> {:ok, Enum.reverse(elements)}
      {:error, _} = error -> error
    end
  end
end
