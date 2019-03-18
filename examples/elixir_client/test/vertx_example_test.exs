defmodule VertxExampleTest do
  use ExUnit.Case
  doctest VertxExample

  test "greets the world" do
    assert VertxExample.hello() == :world
  end
end
