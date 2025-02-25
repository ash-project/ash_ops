defmodule AshMixTest do
  use ExUnit.Case
  doctest AshMix

  test "greets the world" do
    assert AshMix.hello() == :world
  end
end
