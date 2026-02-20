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
  def handle_in("audio_chunk", %{"data" => base64_data}, socket) when is_binary(base64_data) do
    # Decode base64 to binary
    binary_data = Base.decode64!(base64_data)
    OtpRadio.StationOne.Broadcaster.ingest_chunk(binary_data)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("audio_chunk", _payload, socket) do
    Logger.warning("Received audio_chunk without valid data field")
    {:reply, {:error, %{reason: "invalid data"}}, socket}
  end
end
