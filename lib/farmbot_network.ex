defmodule FarmbotNetwork do
  alias FarmbotNetwork.{
    WifiHotspot,
    WifiDhcp,
    WifiStatic,
    WiredDhcp,
    WiredStatic
  }
  defmodule Settings do
    defstruct [
      :ipv4_method,
      :ipv4_address,
      :ipv4_gateway,
      :ipv4_subnet_mask,
      :ipv4_broadcast,
      :domain,
      :nameservers,

      :ssid,
      :psk,
      :key_mgmt,

      :mode
    ]
  end

  @required_static_fields [:ipv4_address, :ipv4_gateway, :ipv4_subnet_mask, :ipv4_broadcast, :domain, :nameservers]

  def setup(interface, settings) when is_map(settings) do
    case validate_settings(interface, settings) do
      {:ok, handler_module, settings} ->
        add_interface(interface, handler_module, settings)
      {:error, reason} -> {:error, reason}
    end
  end

  def add_interface(interface, module, settings) do
    case GenServer.whereis(interface) do
      pid when is_pid(pid) ->
        :ok = teardown(interface)
      nil -> :ok
    end
    GenServer.start_link(module, [interface, settings], [name: name(interface)])
  end

  def teardown(interface) do
    GenServer.call(name(interface), :teardown)
  end

  def scan(<<"w", _ :: binary>> = interface) do
    GenServer.call(name(interface), :scan)
  end

  def name(interface) do
    :"#{interface}.worker"
  end

  # Wireless.
  def validate_settings("w" <> _ = interface, settings) do
    with {:ok, settings} <- check_ip_settings(settings),
         {:ok, settings} <- check_wireless_security_settings(settings),
         {:ok, module} <- check_mode(interface, settings) do
           {:ok, module, settings}
         else
           {:error, key, reason} -> {:error, "Failed to validate key: #{key} #{reason}"}
         end
  end

  # Wired
  def validate_settings("e" <> _ = interface, settings) do
    with {:ok, settings} <- check_ip_settings(settings),
         {:ok, module} <- check_mode(interface, settings) do
           {:ok, module, settings}
         else
           {:error, key, reason} -> {:error, "Failed to validate key: #{key} #{reason}"}
         end
  end

  def check_ip_settings(%Settings{ipv4_method: :dhcp} = settings) do
    {:ok, %{settings | ipv4_address: nil, ipv4_gateway: nil, ipv4_subnet_mask: nil, ipv4_broadcast: nil}}
  end

  def check_ip_settings(%Settings{ipv4_method: :dhcp_server} = settings) do
    Map.take(settings, @required_static_fields)
    |> Enum.find(&is_nil(elem(&1, 1)))
    |> case do
      [] -> {:ok, settings}
      {field, value} -> {:error, field, "#{inspect value} is not a valid value for: #{field}"}
    end
  end

  def check_ip_settings(%Settings{ipv4_method: :static} = settings) do
    Map.take(settings, @required_static_fields)
    |> Enum.find(&is_nil(elem(&1, 1)))
    |> case do
      [] -> {:ok, settings}
      {field, value} -> {:error, field, "#{inspect value} is not a valid value for: #{field}"}
    end
  end

  def check_wireless_security_settings(%Settings{ssid: nil} = _settings), do: {:error, :ssid, "ssid can't be empty"}
  def check_wireless_security_settings(%Settings{key_mgmt: "NONE"} = settings) do
    {:ok, %{settings | psk: nil}}
  end

  def check_wireless_security_settings(%Settings{key_mgmt: "WPA-PSK", psk: <<_ :: binary>>} = settings) do
    {:ok, settings}
  end

  def check_wireless_security_settings(%Settings{key_mgmt: "WPA-PSK", psk: _} = _settings) do
    {:error, :psk, "psk can't be blank when using WPA-PSK"}
  end

  def check_mode("w" <> _ = _iface, %Settings{mode: :hotspot, ipv4_method: :dhcp_server, ssid: <<_ ::binary >>} = _settings) do
    {:ok, WifiHotspot}
  end

  def check_mode(_, %Settings{mode: :hotspot} = _settings) do
    {:error, :mode, "Bad hotspot settings"}
  end

  def check_mode("w" <> _ = _iface, %Settings{mode: :client, ipv4_method: :dhcp} = _settings) do
    {:ok, WifiDhcp}
  end

  def check_mode("w" <> _ = _iface, %Settings{mode: :client, ipv4_method: :static} = _settings) do
    {:ok, WifiStatic}
  end

  def check_mode("e" <> _ = _iface, %Settings{mode: :client, ipv4_method: :dhcp} = _settings) do
    {:ok, WiredDhcp}
  end

  def check_mode("e" <> _ = _iface, %Settings{mode: :client, ipv4_method: :static} = _settings) do
    {:ok, WiredStatic}
  end
end
