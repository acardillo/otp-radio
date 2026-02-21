defmodule OtpRadio.Station.Supervisor do
  @moduledoc """
  Supervisor for one station's process tree (Server, Broadcaster, Distributor).

  Started dynamically by OtpRadio.StationSupervisor (DynamicSupervisor) when
  a station is created. Registered in the Registry under {:station_supervisor, station_id}
  so we can look up and stop the tree by station_id.

  ## Strategy: rest_for_one

  If Server crashes → restart Server, then Broadcaster, then Distributor.
  If Broadcaster crashes → restart Broadcaster, then Distributor.
  If Distributor crashes → restart only Distributor.

  This keeps dependencies in order: Server has no station deps; Broadcaster
  uses Distributor; Distributor is leaf.
  """

  use Supervisor

  @doc """
  Starts the per-station supervisor. Registered via Registry for lookup by station_id.
  """
  def start_link(opts) do
    station_id = Keyword.fetch!(opts, :station_id)
    via = {:via, Registry, {OtpRadio.StationRegistry, {:station_supervisor, station_id}}}
    Supervisor.start_link(__MODULE__, opts, name: via)
  end

  @impl true
  def init(opts) do
    station_id = Keyword.fetch!(opts, :station_id)
    name = Keyword.get(opts, :name, "Station #{station_id}")

    # Each child is registered in the Registry via its own start_link (via_tuple).
    # Order matters for rest_for_one: Server first, then Broadcaster, then Distributor.
    children = [
      {OtpRadio.Station.Server, [station_id: station_id, name: name]},
      {OtpRadio.Station.Broadcaster, [station_id: station_id]},
      {OtpRadio.Station.Distributor, [station_id: station_id]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
