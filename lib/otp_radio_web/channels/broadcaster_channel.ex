defmodule OtpRadioWeb.BroadcasterChannel do
  @moduledoc """
  Phoenix Channel for broadcaster WebSocket connections.

  Topic: "broadcaster:<station_id>". Looks up the station via Registry before
  accepting join; forwards audio to that station's Station.Broadcaster process.
  """

  use Phoenix.Channel
  require Logger

  @impl true
  def join("broadcaster:" <> station_id, _params, socket) when byte_size(station_id) > 0 do
    case Registry.lookup(OtpRadio.StationRegistry, {:station_broadcaster, station_id}) do
      [{_pid, _}] ->
        Logger.info("Broadcaster connected to station_id=#{station_id}")
        broadcaster = OtpRadio.Station.Broadcaster.via_tuple(station_id)
        OtpRadio.Station.Broadcaster.reset_sequence(broadcaster)
        {:ok, socket}

      [] ->
        Logger.warning("Broadcaster join rejected: station not found station_id=#{station_id}")
        {:error, %{reason: "station not found"}}
    end
  end

  def join("broadcaster:" <> _rest, _params, _socket) do
    {:error, %{reason: "invalid topic"}}
  end

  @impl true
  def handle_in("audio_chunk", %{"data" => base64_data}, socket) when is_binary(base64_data) do
    station_id = get_station_id(socket)
    broadcaster = OtpRadio.Station.Broadcaster.via_tuple(station_id)
    binary_data = Base.decode64!(base64_data)
    OtpRadio.Station.Broadcaster.ingest_chunk(broadcaster, binary_data)
    {:reply, :ok, socket}
  end

  def handle_in("audio_chunk", _payload, socket) do
    Logger.warning("Received audio_chunk without valid data field")
    {:reply, {:error, %{reason: "invalid data"}}, socket}
  end

  def handle_in("listener_count", _params, socket) do
    station_id = get_station_id(socket)

    case OtpRadio.StationManager.get_station(station_id) do
      {:ok, server_pid} ->
        %{listener_count: count} = OtpRadio.Station.Server.get_status(server_pid)
        {:reply, {:ok, %{count: count}}, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "station not found"}}, socket}
    end
  end

  defp get_station_id(socket) do
    "broadcaster:" <> station_id = socket.topic
    station_id
  end
end
