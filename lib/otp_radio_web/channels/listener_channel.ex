defmodule OtpRadioWeb.ListenerChannel do
  @moduledoc """
  Phoenix Channel for listener WebSocket connections.

  Handles listener subscriptions to audio streams. Listeners receive
  buffered chunks on join (for smooth startup) and then receive live
  chunks via PubSub.
  """

  use Phoenix.Channel
  require Logger

  @impl true
  def join("listener:one", _params, socket) do
    Logger.info("Listener connected")

    # Subscribe to PubSub audio topic
    Phoenix.PubSub.subscribe(OtpRadio.PubSub, "station:one:audio")

    # Get buffered chunks for catch-up
    buffer = OtpRadio.StationOne.Distributor.get_buffer()

    # Send buffered chunks immediately
    Enum.each(buffer, fn chunk ->
      push(socket, "audio", %{
        data: Base.encode64(chunk.data),
        sequence: chunk.sequence,
        size: chunk.size
      })
    end)

    # Increment listener count
    OtpRadio.StationOne.Server.increment_listeners()

    Logger.info("Sent #{length(buffer)} buffered chunks to listener")

    {:ok, socket}
  end

  @impl true
  def handle_info({:audio_chunk, chunk}, socket) do
    # Push live audio chunk to client
    push(socket, "audio", %{
      data: Base.encode64(chunk.data),
      sequence: chunk.sequence,
      size: chunk.size
    })

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, _socket) do
    # Decrement listener count on disconnect
    OtpRadio.StationOne.Server.decrement_listeners()
    Logger.info("Listener disconnected")
    :ok
  end
end
