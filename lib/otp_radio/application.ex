defmodule OtpRadio.Application do
  @moduledoc """
  Application entry point for OTP Radio.
  """

  use Application

  @impl true
  def start(_type, _args) do
    result = Supervisor.start_link(
      [
        {Phoenix.PubSub, name: OtpRadio.PubSub},
        {Registry, keys: :unique, name: OtpRadio.StationRegistry},
        OtpRadio.StationSupervisor,
        OtpRadioWeb.Endpoint
      ],
      [ strategy: :one_for_one, name: OtpRadio.Supervisor ]
    )

    for _ <- 1..4, do: OtpRadio.StationManager.create_station()

    result
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OtpRadioWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
