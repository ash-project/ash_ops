defmodule AshOps.Task.ActionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  setup do
    ansi_enabled? = Application.get_env(:elixir, :ansi_enabled)
    Application.put_env(:elixir, :ansi_enabled, false)

    on_exit(fn ->
      Application.put_env(:elixir, :ansi_enabled, ansi_enabled?)
    end)
  end

  test "a resource is encoded" do
    id = Ash.UUID.generate()

    output =
      capture_io(fn ->
        Mix.Task.rerun("ash_ops.example.publish_post", [id, "platform"])
      end)

    assert output =~ ~r/id: #{id}/m
  end
end
