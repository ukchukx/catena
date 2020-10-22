defmodule CatenaTest do
  use ExUnit.Case
  doctest Catena

  test "greets the world" do
    assert Catena.hello() == :world
  end
end
