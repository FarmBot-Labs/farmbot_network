defmodule FarmbotNetworkTest do
  use ExUnit.Case
  doctest FarmbotNetwork

  test "greets the world" do
    assert FarmbotNetwork.hello() == :world
  end
end
