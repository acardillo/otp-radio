defmodule OtpRadio.StationManager do
  @moduledoc """
  API for creating, stopping, and listing stations (dynamic OTP processes).

  Uses DynamicSupervisor to start stations on demand and Registry for lookup.
  Does not start any stations at app boot; stations exist only after create_station/2.
  """

  require Logger

  @doc """
  Creates a new station and starts its supervision tree.

  Starts OtpRadio.Station.Supervisor under the DynamicSupervisor; that supervisor
  starts Server, Broadcaster, and Distributor for this station_id.

  ## Parameters

    * `station_id` - Unique string id (e.g. "alpha"). Must be non-empty.
    * `name` - Display name (e.g. "Alpha Station").

  ## Returns

    * `{:ok, pid}` - Station supervisor started.
    * `{:error, {:already_started, pid}}` - A station with this station_id already exists.
    * `{:error, reason}` - Invalid args or start_child failed.

  ## Examples

      StationManager.create_station("alpha", "Alpha Station")
      StationManager.create_station("beta", "Beta Station")
  """
  def create_station(station_id, name)
      when is_binary(station_id) and byte_size(station_id) > 0 and is_binary(name) do
    child_spec = {
      OtpRadio.Station.Supervisor,
      [station_id: station_id, name: name]
    }

    case DynamicSupervisor.start_child(OtpRadio.StationSupervisor, child_spec) do
      {:ok, pid} ->
        Logger.info("Station created: station_id=#{station_id} pid=#{inspect(pid)}")
        {:ok, pid}

      {:error, {:already_started, _pid}} = err ->
        err

      {:error, _reason} = err ->
        err
    end
  end

  def create_station(_station_id, _name), do: {:error, :invalid_args}

  @doc """
  Stops a station and all its processes (Server, Broadcaster, Distributor).

  Looks up the station's supervisor in the Registry and terminates it;
  DynamicSupervisor removes it from its children.
  """
  def stop_station(station_id) when is_binary(station_id) do
    case Registry.lookup(OtpRadio.StationRegistry, {:station_supervisor, station_id}) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(OtpRadio.StationSupervisor, pid)
        Logger.info("Station stopped: station_id=#{station_id}")
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  def stop_station(_), do: {:error, :invalid_args}

  @doc """
  Returns a list of all active stations for API/UI.

  Discovers stations by querying the Registry for all {:station_server, _} keys
  (structure in Registry is {key, pid, value}), then fetches status from each Server.
  """
  def list_stations do
    # Registry stores {key, pid, value}; select all then filter for station_server keys
    OtpRadio.StationRegistry
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(fn {key, _pid} ->
      is_tuple(key) and tuple_size(key) == 2 and elem(key, 0) == :station_server
    end)
    |> Enum.map(fn {{:station_server, station_id}, pid} ->
      status = OtpRadio.Station.Server.get_status(pid)

      %{
        id: station_id,
        name: status.name,
        listener_count: status.listener_count
      }
    end)
  end

  @doc """
  Looks up a station by station_id. Returns the Server pid if the station exists.
  """
  def get_station(station_id) when is_binary(station_id) do
    case Registry.lookup(OtpRadio.StationRegistry, {:station_server, station_id}) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def get_station(_), do: {:error, :invalid_args}

  # ---------------------------------------------------------------------------
  # TESTING SCRIPT (run in IEx to verify OTP patterns)
  # ---------------------------------------------------------------------------
  # Start app: mix phx.server (or iex -S mix phx.server)
  #
  # 1. No stations at startup:
  #    OtpRadio.StationManager.list_stations()
  #    # => []
  #
  # 2. Create stations A and B:
  #    OtpRadio.StationManager.create_station("alpha", "Alpha Station")
  #    OtpRadio.StationManager.create_station("beta", "Beta Station")
  #    OtpRadio.StationManager.list_stations()
  #    # => [%{id: "alpha", ...}, %{id: "beta", ...}]
  #
  # 3. Broadcast to alpha, listen on alpha (use web clients: broadcaster.html
  #    with station_id "alpha", listener.html with Alpha Station selected).
  #
  # 4. Listen to beta without broadcasting => silence (works).
  #
  # 5. Crash station alpha's broadcaster (fault isolation):
  #    [{pid, _}] = Registry.lookup(OtpRadio.StationRegistry, {:station_broadcaster, "alpha"})
  #    Process.exit(pid, :kill)
  #    # Alpha restarts (rest_for_one); beta unaffected. List stations again.
  #
  # 6. Stop station alpha:
  #    OtpRadio.StationManager.stop_station("alpha")
  #    OtpRadio.StationManager.list_stations()
  #    # => [%{id: "beta", ...}]
  #
  # 7. Web client: listener dropdown shows stations from GET /api/stations;
  #    switch between stations and listen.
  # ---------------------------------------------------------------------------
end
