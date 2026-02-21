defmodule OtpRadio.Station.Server do
  @moduledoc """
  GenServer that manages a single station's state and metadata.

  Parameterized by `station_id`: each station has its own Server process.
  Registered via Registry (via_tuple) so channels and other processes can
  look up the process by station_id without passing the pid around.

  ## via_tuple addressing

  This process is registered as:
      {:via, Registry, {OtpRadio.StationRegistry, {:station_server, station_id}}}

  So you can call `GenServer.call(via_tuple, :get_status)` from anywhere
  after resolving the via_tuple with `Registry.lookup(OtpRadio.StationRegistry, {:station_server, station_id})`.
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the station server for the given station_id.

  Registers the process in OtpRadio.StationRegistry under key
  `{:station_server, station_id}` so it can be found by station_id.

  ## Options

    * `:station_id` (required) - Unique string id for the station (e.g. "alpha")
    * `:name` (optional) - Display name (default: "Station \{station_id\}")

  ## Examples

      OtpRadio.Station.Server.start_link(station_id: "alpha", name: "Alpha Station")
  """
  def start_link(opts) do
    station_id = Keyword.fetch!(opts, :station_id)
    display_name = Keyword.get(opts, :name, "Station #{station_id}")

    # via_tuple: allows any process to send messages to this server by station_id
    # without holding a pid. Registry ensures one process per key.
    via = via_tuple(station_id)
    GenServer.start_link(__MODULE__, %{station_id: station_id, name: display_name}, name: via)
  end

  @doc """
  Returns the via_tuple used to register this station's Server in the Registry.

  Use this when building child specs so the supervisor registers the process
  under the correct key.
  """
  def via_tuple(station_id) do
    {:via, Registry, {OtpRadio.StationRegistry, {:station_server, station_id}}}
  end

  @doc """
  Returns the current station state (name, status, listener_count, etc.).

  Call via the process registered for this station (e.g. from StationManager
  or after Registry.lookup).
  """
  def get_status(server) do
    GenServer.call(server, :get_status)
  end

  @doc """
  Increments the listener count by 1. Call when a listener joins the station.
  """
  def increment_listeners(server) do
    GenServer.cast(server, :increment_listeners)
  end

  @doc """
  Decrements the listener count by 1. Call when a listener leaves the station.
  """
  def decrement_listeners(server) do
    GenServer.cast(server, :decrement_listeners)
  end

  # Server callbacks

  @impl true
  def init(initial) do
    state = %{
      station_id: initial.station_id,
      name: initial.name,
      status: :idle,
      listener_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info("Station.Server started for station_id=#{state.station_id}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:increment_listeners, state) do
    {:noreply, %{state | listener_count: state.listener_count + 1}}
  end

  @impl true
  def handle_cast(:decrement_listeners, state) do
    {:noreply, %{state | listener_count: max(0, state.listener_count - 1)}}
  end
end
