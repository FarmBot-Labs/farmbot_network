defmodule FarmbotNetwork.MixProject do
  use Mix.Project

  def project do
    [
      app: :farmbot_network,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make | Mix.compilers()],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      # mod: {FarmbotNetwork.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nerves_wpa_supplicant, github: "nerves-project/nerves_wpa_supplicant", override: true},
      {:dhcp_server, "~> 0.3.0"},
      {:nerves_network_interface, "~> 0.4.4"},
      {:elixir_make, "~> 0.4.1", runtime: false}
    ]
  end
end
