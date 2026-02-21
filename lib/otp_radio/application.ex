defmodule OtpRadio.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Registry MUST be started before any process that uses it for via_tuple naming.
    # Keys: :unique ensures one process per key (e.g. one Server per station_id).
    # Placed before Endpoint so channels can look up stations on join.
    children = [
      OtpRadioWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:otp_radio, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OtpRadio.PubSub},
      {Registry, keys: :unique, name: OtpRadio.StationRegistry},
      OtpRadio.StationSupervisor,
      OtpRadioWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OtpRadio.Supervisor]
    result = Supervisor.start_link(children, opts)
    OtpRadio.StationBootstrap.bootstrap()
    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OtpRadioWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
