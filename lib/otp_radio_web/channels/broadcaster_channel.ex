defmodule OtpRadioWeb.BroadcasterChannel do
  @moduledoc """
  Phoenix Channel for broadcaster WebSocket connections.

  Handles audio chunk ingestion from the broadcaster client
  and forwards chunks to the StationOne.Broadcaster GenServer.
  """

  use Phoenix.Channel
  require Logger

  @impl true
  def join("broadcaster:" <> _station_id, _params, socket) do
    Logger.info("Broadcaster connected")
    {:ok, socket}
  end

  @impl true
  def handle_in("audio_chunk", %{"data" => data}, socket) do
    # Forward binary audio data to Broadcaster GenServer
    OtpRadio.StationOne.Broadcaster.ingest_chunk(data)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("audio_chunk", _payload, socket) do
    Logger.warning("Received audio_chunk without data field")
    {:reply, {:error, %{reason: "missing data field"}}, socket}
  end
end
