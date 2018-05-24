defmodule FarmbotNetwork.WiredStatic do
  use GenServer
  require Logger
  alias Nerves.NetworkInterface, as: NI

  defmodule State do
    defstruct [:settings, :interface, :context]
  end

  def init([interface, settings]) do

    # Register for nerves_network_interface events
    {:ok, _} = Registry.register(NI, interface, [])

    state = struct(State, settings: settings, interface: interface, removed: :ifadded)
    state = consume(state.context, :ifadded, state)
    {:ok, state}
  end

  def terminate(_reason, state) do
    :ok = NI.ifdown(state.interface)
  end

  def handle_call(:teardown, _, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_info({NI, _, _ifstate} = event, s) do
    event = handle_registry_event(event)
    s = consume(s.context, event, s)
    {:noreply, s}
  end

  defp handle_registry_event({NI, :ifadded, _state}) do
    :ifadded
  end

  # :ifmoved occurs on systems that assign stable names to removable
  # interfaces. I.e. the interface is added under the dynamically chosen
  # name and then quickly renamed to something that is stable across boots.
  defp handle_registry_event({NI, :ifmoved, _state}) do
    :ifadded
  end

  defp handle_registry_event({NI, :ifremoved, _state}) do
    :ifremoved
  end

  # Filter out ifup and ifdown events
  # :is_up reports whether the interface is enabled or disabled (like by the wifi kill switch)
  # :is_lower_up reports whether the interface as associated with an AP
  defp handle_registry_event({NI, :ifchanged, %{interface: _interface, is_lower_up: true}}) do
    :ifup
  end

  defp handle_registry_event({NI, :ifchanged, %{interface: _interface, is_lower_up: false}}) do
    :ifdown
  end

  defp handle_registry_event({NI, _event, %{interface: _interface}}) do
    :noop
  end

  defp consume(_, :noop, state), do: state

  ## Context: removed
  defp consume(:removed, :ifadded, state) do
    :ok = NI.ifup(state.interface)
    goto_context(state, :down)
  end

  ## Context: :down
  defp consume(:down, :ifup, state) do
    state
    |> configure
    |> goto_context(:up)
  end

  defp consume(:down, :ifdown, state), do: state

  defp consume(:down, :ifremoved, state) do
    state
    |> goto_context(:removed)
  end

  ## Context: :up
  defp consume(:up, :ifup, state), do: state

  defp consume(:up, :ifdown, state) do
    state
    |> deconfigure
    |> goto_context(:down)
  end

  defp consume(:up, :ifadded, state), do: state

  defp goto_context(state, newcontext) do
    %State{state | context: newcontext}
  end

  defp configure(state) do
    :ok = NI.setup(state.interface, state.settings)
    :ok = Resolvconf.setup(Resolvconf, state.interface, state.settings)
    state
  end

  defp deconfigure(state) do
    :ok = Resolvconf.clear(Resolvconf, state.interface)
    state
  end
end
