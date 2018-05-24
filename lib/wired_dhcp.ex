defmodule FarmbotNetwork.WiredDhcp do
  use GenServer

  defmodule State do
    defstruct []
  end

  def init([iface, settings]) do

  end

  def handle_call(:teardown, _, state) do
    {:stop, :normal, :ok, state}
  end
end
