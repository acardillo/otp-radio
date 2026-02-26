defmodule OtpRadio.StationManager do
  @moduledoc """
  API for creating, stopping, and listing stations (dynamic OTP processes).

  Uses DynamicSupervisor to start stations on demand and Registry for lookup.
  Stations get an auto-incrementing id; call create_station/0 with no args.
  """

  require Logger

  @doc """
  Creates a new station with an auto-assigned id and starts its supervision tree.

  The next id is derived from the Registry (max existing numeric id + 1). The station's
  display name is the id. Returns the new station_id so callers can use it.

  ## Returns

    * `{:ok, station_id}` - Station started; station_id is a string (e.g. "1").
    * `{:error, reason}` - start_child failed.
  """
  def create_station do
    station_id = next_station_id_from_registry()
    child_spec = {OtpRadio.Station.Supervisor, [station_id: station_id, name: station_id]}

    case DynamicSupervisor.start_child(OtpRadio.StationSupervisor, child_spec) do
      {:ok, _pid} ->
        Logger.info("Station created: station_id=#{station_id}")
        {:ok, station_id}

      {:error, {:already_started, _pid}} ->
        create_station()

      {:error, _reason} = err ->
        err
    end
  end

  defp next_station_id_from_registry do
    OtpRadio.StationRegistry
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
    |> Enum.filter(fn key ->
      is_tuple(key) and tuple_size(key) == 2 and elem(key, 0) == :station_supervisor
    end)
    |> Enum.map(fn {:station_supervisor, id} -> id end)
    |> Enum.uniq()
    |> Enum.map(&Integer.parse/1)
    |> Enum.filter(&match?({_num, _}, &1))
    |> Enum.map(fn {num, _} -> num end)
    |> Enum.concat([0])
    |> Enum.max()
    |> Kernel.+(1)
    |> Integer.to_string()
  end

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
end
