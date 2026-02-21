defmodule OtpRadioWeb.ListenerChannel do
  @moduledoc """
  Phoenix Channel for listener WebSocket connections.

  Topic: "listener:<station_id>". Looks up station via Registry; subscribes to
  "station:<station_id>:audio" and forwards buffered + live chunks. Handles
  station not found gracefully.
  """

  use Phoenix.Channel
  require Logger

  @impl true
  def join("listener:" <> station_id, _params, socket) when byte_size(station_id) > 0 do
    case OtpRadio.StationManager.get_station(station_id) do
      {:ok, _server_pid} ->
        Logger.info("Listener connected to station_id=#{station_id}")

        Phoenix.PubSub.subscribe(
          OtpRadio.PubSub,
          OtpRadio.Station.Distributor.topic_for_station(station_id)
        )

        send(self(), :after_join)
        {:ok, socket}

      {:error, :not_found} ->
        Logger.warning("Listener join rejected: station not found station_id=#{station_id}")
        {:error, %{reason: "station not found"}}
    end
  end

  def join("listener:" <> _rest, _params, _socket) do
    {:error, %{reason: "invalid topic"}}
  end

  @impl true
  def handle_info(:after_join, socket) do
    station_id = get_station_id(socket)
    distributor = OtpRadio.Station.Distributor.via_tuple(station_id)
    {:ok, server_pid} = OtpRadio.StationManager.get_station(station_id)
    buffer = OtpRadio.Station.Distributor.get_buffer(distributor)

    Enum.each(buffer, fn chunk ->
      push(socket, "audio", %{
        data: Base.encode64(chunk.data),
        sequence: chunk.sequence,
        size: chunk.size
      })
    end)

    OtpRadio.Station.Server.increment_listeners(server_pid)
    Logger.info("Sent #{length(buffer)} buffered chunks to listener for station_id=#{station_id}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:audio_chunk, chunk}, socket) do
    push(socket, "audio", %{
      data: Base.encode64(chunk.data),
      sequence: chunk.sequence,
      size: chunk.size
    })

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    station_id = get_station_id(socket)

    case OtpRadio.StationManager.get_station(station_id) do
      {:ok, server_pid} ->
        OtpRadio.Station.Server.decrement_listeners(server_pid)

      _ ->
        :ok
    end

    Logger.info("Listener disconnected from station_id=#{station_id}")
    :ok
  end

  defp get_station_id(socket) do
    "listener:" <> station_id = socket.topic
    station_id
  end
end
