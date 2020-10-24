defmodule CatenaPersistenceTest do
  use ExUnit.Case
  doctest CatenaPersistence

  test "greets the world" do
    assert CatenaPersistence.hello() == :world
  end
end
