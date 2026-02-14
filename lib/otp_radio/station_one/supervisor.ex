defmodule OtpRadio.StationOne.Supervisor do
  @moduledoc """
  Supervisor for Station One's process tree.

  Manages the three core GenServers (Server, Broadcaster, Distributor)
  with a rest_for_one strategy. This ensures that if a process crashes,
  all processes that depend on it are restarted in order.

  ## Supervision Strategy

  - If Server crashes: restart Server, Broadcaster, and Distributor
  - If Broadcaster crashes: restart Broadcaster and Distributor
  - If Distributor crashes: restart only Distributor
  """

  use Supervisor

  @doc """
  Starts the station supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      OtpRadio.StationOne.Server,
      OtpRadio.StationOne.Broadcaster,
      OtpRadio.StationOne.Distributor
    ]

    # rest_for_one: if a child crashes, restart it and all children after it
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
